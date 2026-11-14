--@ Property Handler
local Jloader = require("@game/ReplicatedStorage/JLoader")
local Config = require("@self/Config")
local RunService = game:GetService("RunService")

local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local function stateOf(controller)
	local state = controller:Scope(Config.Scope)

	if state.jumpLimit == nil then
		state.jumpLimit = Config.BaseJumpPower
		state.jumpCooling = false
	end

	return state
end

local function resolveJumpPower(controller): number
	local state = stateOf(controller)

	if state.launchPower then
		return state.launchPower
	end

	if state.jumpCooling then
		return 0
	end

	return state.jumpLimit
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

local function cancelCooldown(state)
	if state.cooldownThread then
		task.cancel(state.cooldownThread)
		state.cooldownThread = nil
	end
end

function PropertyHandler:InitCharacter(controller)
	if self.CharacterTrove then
		self.CharacterTrove:Destroy()
	end
	local Character = controller.Character
	if not Character then return end

	local state = stateOf(controller)

	cancelCooldown(state)
	state.jumpLimit = Config.BaseJumpPower
	state.jumpCooling = false
	state.launchPower = nil

	local trove = controller.Trove.new()
	self.CharacterTrove = trove

	applyHumanoidProperties(controller)

	trove:Connect(Character.AttributeChanged, function()
		if controller.Character == Character then
			applyHumanoidProperties(controller)
		end
	end)

	trove:Connect(controller.Humanoid.Jumping, function(active: boolean)
		if controller.Character ~= Character or not active or state.jumpCooling then return end

		state.launchPower = controller.Humanoid.JumpPower
		RunService.Heartbeat:Once(function()
			state.launchPower = nil

			if controller.Character == Character then
				applyHumanoidProperties(controller)
			end
		end)

		state.jumpCooling = true
		cancelCooldown(state)
		state.cooldownThread = task.delay(Config.Jump.Cooldown, function()
			if controller.Character ~= Character then return end
			state.cooldownThread = nil
			state.jumpCooling = false
			applyHumanoidProperties(controller)
		end)

		applyHumanoidProperties(controller)
	end)

	trove:Add(function()
		cancelCooldown(state)
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
