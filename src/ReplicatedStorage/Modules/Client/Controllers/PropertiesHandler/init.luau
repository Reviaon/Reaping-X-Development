--@ Property Handler
local Jloader = require(game.ReplicatedStorage.JLoader)
local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEBUG_STATUS_UI = true

local BASE_WALK_SPEED = 10
local BASE_JUMP_POWER = 50

local JUMP_DECAY_STEP = 10
local JUMP_RECOVERY_RATE = 5
local JUMP_RESET_COOLDOWN = 0.5
local JUMP_MIN_POWER = 25
local JUMP_IDLE_RESET = 2

local _decayedJumpPower = BASE_JUMP_POWER
local _statusZeroesJump = false
local _jumpResetPending = false
local _resetThread = nil
local _idleThread = nil

local function resolveJumpPower()
	if _statusZeroesJump or _decayedJumpPower < JUMP_MIN_POWER then
		return 0
	end

	return _decayedJumpPower
end

local function applyHumanoidProperties(controller)
	local Character = controller.Character
	local Humanoid  = controller.Humanoid
	if not Character or not Humanoid then return end

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

	_statusZeroesJump = jumpPower ~= nil and jumpPower <= 0

	local effectiveJump = resolveJumpPower()
	Humanoid.JumpPower = effectiveJump

	if effectiveJump <= 0 and walkSpeed < BASE_WALK_SPEED then
		Humanoid.Jump = false
	end

	
	Humanoid.WalkSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED
	Humanoid.JumpPower = resolveJumpPower()
end

--@ Restarted on every jump. Going JUMP_IDLE_RESET seconds without jumping wipes
--  the accumulated decay entirely, independent of the zeroed-out reset cooldown.
local function cancelIdleReset()
	if _idleThread then
		task.cancel(_idleThread)
		_idleThread = nil
	end
end

local function scheduleIdleReset(controller)
	cancelIdleReset()

	_idleThread = task.delay(JUMP_IDLE_RESET, function()
		_idleThread = nil

		if _decayedJumpPower >= BASE_JUMP_POWER then return end

		_decayedJumpPower = BASE_JUMP_POWER
		applyHumanoidProperties(controller)
	end)
end

local function propertyUpdate(controller, dt)
	local Humanoid = controller.Humanoid
	if not Humanoid then return end

	if not _jumpResetPending and _decayedJumpPower < BASE_JUMP_POWER then
		_decayedJumpPower = math.min(BASE_JUMP_POWER, _decayedJumpPower + JUMP_RECOVERY_RATE * dt)
	end

	Humanoid.WalkSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED
	Humanoid.JumpPower = resolveJumpPower()
end

--@ Displays the character's active status attribute in the debug UI's TextLabel.
--  Only the status with the highest Priority is shown when several are active.
--  The clone and its listener ride the character trove, so they tear down on respawn.
local function setupDebugStatusUI(controller, trove)
	if not controller.Debug then 
		return 
	end

	local Character = controller.Character
	local Head = Character and Character:FindFirstChild("Head")

	if not Head then
		warn("[PropertiesHandler] Debug status UI could not find the character's Head.")
		return
	end

	local Storage = ReplicatedStorage:FindFirstChild("Storage")
	local UIFolder = Storage and Storage:FindFirstChild("UIFolder")
	local DebugTemplate = UIFolder and UIFolder:FindFirstChild("DebugStatusUI")

	if not DebugTemplate then
		warn("[PropertiesHandler] Debug status UI is enabled but Storage.UIFolder.DebugStatusUI is missing.")
		return
	end

	local DebugUI = DebugTemplate:Clone()
	DebugUI.Parent = Head
	trove:Add(DebugUI)

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
end

function PropertyHandler:InitCharacter(controller)
	local Character = controller.Character
	if not Character then return end

	if _resetThread then
		task.cancel(_resetThread)
		_resetThread = nil
	end
	cancelIdleReset()
	_decayedJumpPower = BASE_JUMP_POWER
	_statusZeroesJump = false
	_jumpResetPending = false

	local trove = controller.Trove.new()

	applyHumanoidProperties(controller)
	setupDebugStatusUI(controller, trove)

	trove:Connect(Character.AttributeChanged, function()
		applyHumanoidProperties(controller)
	end)

	trove:Connect(controller.Humanoid.Jumping, function(active)
		if not active or _jumpResetPending then return end

		_decayedJumpPower = math.max(0, _decayedJumpPower - JUMP_DECAY_STEP)

		if _decayedJumpPower < JUMP_MIN_POWER then
			_decayedJumpPower = 0
		end

		if _decayedJumpPower <= 0 then
			--@ Fully decayed: the zeroed-out cooldown owns the reset from here.
			cancelIdleReset()

			_jumpResetPending = true
			_resetThread = task.delay(JUMP_RESET_COOLDOWN, function()
				_resetThread = nil
				_jumpResetPending = false
				_decayedJumpPower = BASE_JUMP_POWER
				applyHumanoidProperties(controller)
			end)
		else
			scheduleIdleReset(controller)
		end

		applyHumanoidProperties(controller)
	end)

	trove:Add(function()
		if _resetThread then
			task.cancel(_resetThread)
			_resetThread = nil
		end
		cancelIdleReset()
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
