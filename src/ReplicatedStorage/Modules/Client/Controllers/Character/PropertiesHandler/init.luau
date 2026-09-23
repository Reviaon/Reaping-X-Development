--@ Property Handler
local Jloader = require(game.ReplicatedStorage.JLoader)
local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local Config = require(script.Config)

local function stateOf(controller)
	local state = controller:Scope(Config.Scope)

	if state.decayedJumpPower == nil then
		state.decayedJumpPower = Config.BaseJumpPower
		state.jumpLimit = Config.BaseJumpPower
		state.jumpResetPending = false
	end

	return state
end

local function resolveJumpPower(controller)
	local state = stateOf(controller)

	if state.decayedJumpPower < Config.Jump.MinPower then
		return 0
	end

	return math.min(state.decayedJumpPower, state.jumpLimit)
end

local function applyHumanoidProperties(controller)
	local Character = controller.Character
	local Humanoid = controller.Humanoid
	if not Character or not Humanoid then return end

	local state = stateOf(controller)
	local properties = controller.StatusService:ResolveProperties(Character, {
		WalkSpeed = Config.BaseWalkSpeed,
		JumpPower = Config.BaseJumpPower,
	})
	state.jumpLimit = math.max(0, properties.JumpPower)
	local walkSpeed = math.max(0, properties.WalkSpeed)
	local jumpPower = resolveJumpPower(controller)
	controller:Set("GoalSpeed", walkSpeed)
	Humanoid.WalkSpeed = walkSpeed
	Humanoid.JumpPower = jumpPower
	if jumpPower <= 0 then
		Humanoid.Jump = false
	end
end

--@ Restarted on every jump. Going Jump.IdleReset seconds without jumping wipes
--  the accumulated decay entirely, independent of the zeroed-out reset cooldown.
local function cancelIdleReset(state)

	if state.idleThread then
		task.cancel(state.idleThread)
		state.idleThread = nil
	end
end

local function scheduleIdleReset(controller)
	cancelIdleReset(stateOf(controller))

	local state = stateOf(controller)
	local Character = controller.Character

	state.idleThread = task.delay(Config.Jump.IdleReset, function()
		if controller.Character ~= Character then return end
		state.idleThread = nil

		if state.decayedJumpPower >= Config.BaseJumpPower then return end

		state.decayedJumpPower = Config.BaseJumpPower
		applyHumanoidProperties(controller)
	end)
end

function PropertyHandler:InitCharacter(controller)
	if self.CharacterTrove then
		self.CharacterTrove:Destroy()
	end
	local Character = controller.Character
	if not Character then return end

	local state = stateOf(controller)

	if state.resetThread then
		task.cancel(state.resetThread)
		state.resetThread = nil
	end
	cancelIdleReset(stateOf(controller))
	state.decayedJumpPower = Config.BaseJumpPower
	state.jumpLimit = Config.BaseJumpPower
	state.jumpResetPending = false

	local trove = controller.Trove.new()
	self.CharacterTrove = trove

	applyHumanoidProperties(controller)

	trove:Connect(Character.AttributeChanged, function()
		if controller.Character == Character then
			applyHumanoidProperties(controller)
		end
	end)

	trove:Connect(controller.Humanoid.Jumping, function(active)
		if controller.Character ~= Character or not active or state.jumpResetPending then return end

		state.decayedJumpPower = math.max(0, state.decayedJumpPower - Config.Jump.DecayStep)

		if state.decayedJumpPower < Config.Jump.MinPower then
			state.decayedJumpPower = 0
		end

		if state.decayedJumpPower <= 0 then
			--@ Fully decayed: the zeroed-out cooldown owns the reset from here.
			cancelIdleReset(stateOf(controller))

			state.jumpResetPending = true
			state.resetThread = task.delay(Config.Jump.ResetCooldown, function()
				if controller.Character ~= Character then return end
				state.resetThread = nil
				state.jumpResetPending = false
				state.decayedJumpPower = Config.BaseJumpPower
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
		cancelIdleReset(state)
	end)


	trove:Connect(controller.Humanoid.Died, function()
		trove:Clean()
	end)

	trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			trove:Clean()
		end
	end)
end

return PropertyHandler
