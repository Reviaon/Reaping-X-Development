--@ Property Handler
local Jloader = require(game.ReplicatedStorage.JLoader)
local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")

local BASE_WALK_SPEED = 10
local BASE_JUMP_POWER = 50
local SPEED_LERP_ALPHA = 8

local JUMP_DECAY_STEP = 10
local JUMP_RECOVERY_RATE = 5
local JUMP_RESET_COOLDOWN = 3

local _decayedJumpPower = BASE_JUMP_POWER
local _statusJumpOverride = nil
local _jumpResetPending = false
local _resetThread = nil

local function lerp(a, b, t)
	return a + (b - a) * t
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

	_statusJumpOverride = jumpPower

	local effectiveJump = jumpPower or _decayedJumpPower
	Humanoid.JumpPower = math.max(effectiveJump, 0)

	if effectiveJump <= 0 and walkSpeed < BASE_WALK_SPEED then
		Humanoid.Jump = false
	end
end

local function walkUpdate(controller, dt)
	local Humanoid = controller.Humanoid
	if not Humanoid then return end

	local goalSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED

	Humanoid.WalkSpeed = lerp(
		Humanoid.WalkSpeed,
		goalSpeed,
		math.clamp(SPEED_LERP_ALPHA * dt, 0, 1)
	)

	if not _jumpResetPending and _decayedJumpPower < BASE_JUMP_POWER then
		_decayedJumpPower = math.min(BASE_JUMP_POWER, _decayedJumpPower + JUMP_RECOVERY_RATE * dt)
	end

	Humanoid.JumpPower = math.max(_statusJumpOverride or _decayedJumpPower, 0)
end

function PropertyHandler:InitCharacter(controller)
	local Character = controller.Character
	if not Character then return end

	if _resetThread then
		task.cancel(_resetThread)
		_resetThread = nil
	end
	_decayedJumpPower = BASE_JUMP_POWER
	_statusJumpOverride = nil
	_jumpResetPending = false

	local trove = controller.Trove.new()

	applyHumanoidProperties(controller)

	trove:Connect(Character.AttributeChanged, function()
		applyHumanoidProperties(controller)
	end)

	trove:Connect(controller.Humanoid.Jumping, function(active)
		if not active or _jumpResetPending then return end

		_decayedJumpPower = math.max(0, _decayedJumpPower - JUMP_DECAY_STEP)

		if _decayedJumpPower <= 0 then
			_jumpResetPending = true
			_resetThread = task.delay(JUMP_RESET_COOLDOWN, function()
				_resetThread = nil
				_jumpResetPending = false
				_decayedJumpPower = BASE_JUMP_POWER
				applyHumanoidProperties(controller)
			end)
		end

		applyHumanoidProperties(controller)
	end)

	trove:Add(function()
		if _resetThread then
			task.cancel(_resetThread)
			_resetThread = nil
		end
	end)

	trove:Connect(RunService.RenderStepped, function(dt)
		walkUpdate(controller, dt)
	end)

	trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			trove:Clean()
		end
	end)
end

return PropertyHandler
