--@ Property Handler
local Jloader = require(game.ReplicatedStorage.JLoader)
local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local BASE_WALK_SPEED = 10
local BASE_JUMP_POWER = 50

local JUMP_DECAY_STEP = 10
local JUMP_RECOVERY_RATE = 5
local JUMP_RESET_COOLDOWN = 0.5
local JUMP_MIN_POWER = 25
local JUMP_IDLE_RESET = 2

local SCOPE = "Properties"

local function stateOf(controller)
	local state = controller:Scope(SCOPE)

	if state.decayedJumpPower == nil then
		state.decayedJumpPower = BASE_JUMP_POWER
		state.statusZeroesJump = false
		state.jumpResetPending = false
	end

	return state
end

local function resolveJumpPower(controller)
	local state = stateOf(controller)

	if state.statusZeroesJump or state.decayedJumpPower < JUMP_MIN_POWER then
		return 0
	end

	return state.decayedJumpPower
end

local function applyHumanoidProperties(controller)
	local Character = controller.Character
	local Humanoid  = controller.Humanoid
	if not Character or not Humanoid then return end

	local state = stateOf(controller)
	local walkSpeed, jumpPower, highestPriority = BASE_WALK_SPEED, nil, -math.huge
	local noAutoRotate = false

	local StatusStates = controller.StatusService:GetStatesTable()

	for attrName in Character:GetAttributes() do
		local statusData = StatusStates[attrName]
		if statusData then
			local priority = statusData.Priority or 0
			if priority > highestPriority then
				highestPriority = priority

				if attrName == "NoAutoRotate" then
					noAutoRotate = true
				end

				walkSpeed = statusData.WalkSpeed or walkSpeed
				jumpPower = statusData.JumpPower or jumpPower
			end
		end
	end

	Humanoid.AutoRotate = not noAutoRotate

	controller:Set("GoalSpeed", walkSpeed)
	Humanoid.WalkSpeed = walkSpeed

	state.statusZeroesJump = jumpPower ~= nil and jumpPower <= 0

	local effectiveJump = resolveJumpPower(controller)
	Humanoid.JumpPower = effectiveJump

	if effectiveJump <= 0 and walkSpeed < BASE_WALK_SPEED then
		Humanoid.Jump = false
	end

	
	Humanoid.WalkSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED
	Humanoid.JumpPower = resolveJumpPower(controller)
end

--@ Restarted on every jump. Going JUMP_IDLE_RESET seconds without jumping wipes
--  the accumulated decay entirely, independent of the zeroed-out reset cooldown.
local function cancelIdleReset(controller)
	local state = controller:Scope(SCOPE)

	if state.idleThread then
		task.cancel(state.idleThread)
		state.idleThread = nil
	end
end

local function scheduleIdleReset(controller)
	cancelIdleReset(controller)

	local state = stateOf(controller)

	state.idleThread = task.delay(JUMP_IDLE_RESET, function()
		state.idleThread = nil

		if state.decayedJumpPower >= BASE_JUMP_POWER then return end

		state.decayedJumpPower = BASE_JUMP_POWER
		applyHumanoidProperties(controller)
	end)
end

local function propertyUpdate(controller, dt)
	local Humanoid = controller.Humanoid
	if not Humanoid then return end

	local state = stateOf(controller)

	if not state.jumpResetPending and state.decayedJumpPower < BASE_JUMP_POWER then
		state.decayedJumpPower = math.min(BASE_JUMP_POWER, state.decayedJumpPower + JUMP_RECOVERY_RATE * dt)
	end

	Humanoid.WalkSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED
	Humanoid.JumpPower = resolveJumpPower(controller)
end

--@ Displays the character's active status attribute in the debug UI's TextLabel.
--  Only the status with the highest Priority is shown when several are active.
--  The clone and its listener ride the character trove, so they tear down on respawn.
local function setupDebugStatusUI(controller, trove)
	local Character = controller.Character
	if not Character then return end

	local DebugUI = Character:FindFirstChild("DebugStatusUI", true)

	if not DebugUI then
		local Storage = ReplicatedStorage:FindFirstChild("Storage")
		local UIFolder = Storage and Storage:FindFirstChild("UIFolder")
		local DebugTemplate = UIFolder and UIFolder:FindFirstChild("DebugStatusUI")

		if not DebugTemplate then
			warn("[PropertiesHandler] Debug status UI is enabled but Storage.UIFolder.DebugStatusUI is missing.")
			return
		end

		local Host = Character:FindFirstChild("Head")
			or Character.PrimaryPart
			or Character:FindFirstChildWhichIsA("BasePart")

		if not Host then
			warn("[PropertiesHandler] Debug status UI has nothing to parent to on " .. Character.Name .. ".")
			return
		end

		DebugUI = DebugTemplate:Clone()
		DebugUI.Parent = Host
		trove:Add(DebugUI)
	end

	local StatusLabel = DebugUI:FindFirstChildWhichIsA("TextLabel", true)

	if not StatusLabel then
		warn("[PropertiesHandler] DebugStatusUI has no TextLabel to display statuses in.")
		return
	end

	local StatusStates = controller.StatusService:GetStatesTable()

	local function updateStatusLabel()
		local activeStatus, highestPriority = nil, -math.huge

		for Attribute, Value in Character:GetAttributes() do
			local statusData = StatusStates[Attribute]

			if statusData and Value then
				local priority = statusData.Priority or 0

				if priority > highestPriority then
					highestPriority = priority
					activeStatus = Attribute
				end
			end
		end

		StatusLabel.Text = activeStatus or "None"
	end

	updateStatusLabel()
	trove:Connect(Character.AttributeChanged, updateStatusLabel)

	local DebugService = controller.DebugService

	local function applyVisibility()
		DebugUI.Enabled = DebugService.IsEnabled()
	end

	applyVisibility()
	trove:Add(DebugService.Changed(applyVisibility))
end

function PropertyHandler:InitCharacter(controller)
	local Character = controller.Character
	if not Character then return end

	local state = stateOf(controller)

	if state.resetThread then
		task.cancel(state.resetThread)
		state.resetThread = nil
	end
	cancelIdleReset(controller)
	state.decayedJumpPower = BASE_JUMP_POWER
	state.statusZeroesJump = false
	state.jumpResetPending = false

	local trove = controller.Trove.new()

	applyHumanoidProperties(controller)
	setupDebugStatusUI(controller, trove)

	trove:Connect(Character.AttributeChanged, function()
		applyHumanoidProperties(controller)
	end)

	trove:Connect(controller.Humanoid.Jumping, function(active)
		if not active or state.jumpResetPending then return end

		state.decayedJumpPower = math.max(0, state.decayedJumpPower - JUMP_DECAY_STEP)

		if state.decayedJumpPower < JUMP_MIN_POWER then
			state.decayedJumpPower = 0
		end

		if state.decayedJumpPower <= 0 then
			--@ Fully decayed: the zeroed-out cooldown owns the reset from here.
			cancelIdleReset(controller)

			state.jumpResetPending = true
			state.resetThread = task.delay(JUMP_RESET_COOLDOWN, function()
				state.resetThread = nil
				state.jumpResetPending = false
				state.decayedJumpPower = BASE_JUMP_POWER
				applyHumanoidProperties(controller)
			end)
		else
			scheduleIdleReset(controller)
		end

		applyHumanoidProperties(controller)
	end)

	trove:Add(function()
		if state.resetThread then
			task.cancel(state.resetThread)
			state.resetThread = nil
		end
		cancelIdleReset(controller)
	end)

	--trove:Connect(RunService.RenderStepped, function(dt)
		--propertyUpdate(controller, dt)
	--end)

	trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			trove:Clean()
		end
	end)
end

return PropertyHandler
