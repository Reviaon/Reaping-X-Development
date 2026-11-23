--[[@
	**Startle**: an attack that comes near a passive bird spooks it, hit or miss (`startle`)
	- **Melee:** any swing from within `startle.range` studs of it
	- **Ranged:** a shot whose line passes within `startle.near` studs of it, ahead of the archer
	- **Spooked** birds fly off (`States/FlyOff`) for `startle.duration` seconds; one already in alarm (provoked) ignores it
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Startle = {}

local random = Random.new()

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function reaches(mob, startle: MobTypes.Startle, from: Vector3, direction: Vector3?): boolean
	local position = mob.Root.Position

	if not direction or direction.Magnitude < 1e-3 then
		return (position - from).Magnitude <= startle.range
	end

	local unit = direction.Unit
	local along = (position - from):Dot(unit)
	if along < 0 then return false end

	return (from + unit * along - position).Magnitude <= startle.near
end

function Startle.React(mobs, attacker: Model, origin: Vector3?, direction: Vector3?)
	local root = rootOf(attacker)
	if not root then return end

	local from = origin or root.Position
	local now = os.clock()

	for mob in mobs do
		local startle: MobTypes.Startle? = mob.Config.startle or nil

		if not startle or mob.Dead or not mob.Root or mob:Provoker() then continue end
		if not reaches(mob, startle, from, direction) then continue end

		local board = mob.Blackboard

		board.Spooker = attacker
		board.SpookedUntil = now + random:NextNumber(startle.duration[1], startle.duration[2])
	end
end

return Startle
