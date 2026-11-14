local RunService = game:GetService("RunService")

local StatusLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/StatusLibrary")
local StatusResolver = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/StatusResolver")
local PlayerConfig = require("../PropertiesHandler/Config")

local Config = require("./Config")
local Types = require("./Types")

type Session = Types.Session

local Properties = {}

local function resolve(attributes: { [string]: any }): { [string]: number }
	local defaults = { WalkSpeed = PlayerConfig.BaseWalkSpeed, JumpPower = PlayerConfig.BaseJumpPower }
	return StatusResolver.Resolve(attributes, StatusLibrary.Types, defaults, StatusLibrary.PropertyModes)
end

local function share(full: number, neutral: number): number
	if neutral <= 0 then
		return if full > 0 then 1 else 0
	end

	return math.max(full, 0) / neutral
end

local function jumpShare(jump: Types.Jump, limit: number): number
	if jump.Cooling then return 0 end

	return math.min(PlayerConfig.BaseJumpPower, limit) / PlayerConfig.BaseJumpPower
end

local function cool(session: Session)
	local jump = session.State.Jump

	jump.Cooling = true
	session:Cancel("JumpReset")
	session:Delay("JumpReset", PlayerConfig.Jump.Cooldown, function()
		jump.Cooling = false
		session:Speed()
	end)
end

function Properties.Fresh(): Types.Jump
	return { Cooling = false, Launching = false }
end

function Properties.Apply(session: Session)
	local attributes = session.Character:GetAttributes()
	local own: { [string]: any } = {}
	local statuses: { [string]: boolean } = Config.OwnStatuses

	for name in statuses do
		own[name] = attributes[name]
	end

	local full = resolve(attributes)
	local neutral = resolve(own)
	local state = session.State
	local humanoid = session.Humanoid

	local speed = if state.Attacking then state.StepIn or 0 elseif state.Running then session.RunSpeed else session.WalkSpeed

	humanoid.WalkSpeed = speed * share(full.WalkSpeed, neutral.WalkSpeed)

	if state.Jump.Launching then return end

	local jump = jumpShare(state.Jump, full.JumpPower)

	humanoid.JumpPower = session.JumpPower * jump

	if jump <= 0 then
		humanoid.Jump = false
	end
end

function Properties.Start(session: Session)
	local jump = session.State.Jump

	session.Trove:Connect(session.Humanoid.Jumping, function(active: boolean)
		if not active or jump.Cooling then return end

		jump.Launching = true

		RunService.Heartbeat:Once(function()
			jump.Launching = false
			session:Speed()
		end)

		cool(session)
		session:Speed()
	end)
end

return Properties
