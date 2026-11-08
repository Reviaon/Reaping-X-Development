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
	if jump.Decayed < PlayerConfig.Jump.MinPower then return 0 end

	return math.min(jump.Decayed, limit) / PlayerConfig.BaseJumpPower
end

local function decay(session: Session)
	local jump = session.State.Jump

	jump.Decayed = math.max(0, jump.Decayed - PlayerConfig.Jump.DecayStep)

	if jump.Decayed < PlayerConfig.Jump.MinPower then
		jump.Decayed = 0
	end

	session:Cancel("JumpReset")

	if jump.Decayed <= 0 then
		jump.Pending = true
		session:Delay("JumpReset", PlayerConfig.Jump.ResetCooldown, function()
			jump.Pending = false
			jump.Decayed = PlayerConfig.BaseJumpPower
			session:Speed()
		end)
	else
		session:Delay("JumpReset", PlayerConfig.Jump.IdleReset, function()
			jump.Decayed = PlayerConfig.BaseJumpPower
			session:Speed()
		end)
	end
end

function Properties.Fresh(): Types.Jump
	return { Decayed = PlayerConfig.BaseJumpPower, Pending = false, Launching = false }
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
		if not active or jump.Pending then return end

		jump.Launching = true

		RunService.Heartbeat:Once(function()
			jump.Launching = false
			session:Speed()
		end)

		decay(session)
		session:Speed()
	end)
end

return Properties
