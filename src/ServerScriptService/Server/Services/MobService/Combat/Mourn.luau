--[[@
	**Mourn**: when a mob dies, its own kind close by turn on whoever killed it (`mourn`)
	- **Who answers:** every living mob within `mourn.radius` whose name is the dead mob's (or in `mourn.kinds`)
	- **The killer:** the dead mob's provoker, else the player it was last provoked by, else the nearest player
	- **Answering** provokes them onto the killer and makes their cry due at once, so a flock of MockingJays all cry together
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../Senses/Perception")

local Mourn = {}

local function killerOf(dead, range: number): Model?
	local killer = dead:Provoker() or dead.LastProvoker

	if Perception.IsValidTarget(killer) then return killer end

	return (Perception.NearestPlayer(dead.Root.Position, range))
end

local function answers(mob, dead, mourn: MobTypes.Mourn): boolean
	if mourn.kinds then
		return table.find(mourn.kinds, dead.Name) ~= nil
	end

	return mob.Name == dead.Name
end

function Mourn.React(mobs, dead)
	if not dead.Root then return end

	local origin = dead.Root.Position
	local killer

	for mob in mobs do
		local mourn: MobTypes.Mourn? = mob.Config.mourn or nil

		if not mourn or mob == dead or mob.Dead or not mob.Root then continue end
		if not answers(mob, dead, mourn) or (mob.Root.Position - origin).Magnitude > mourn.radius then continue end

		killer = killer or killerOf(dead, mourn.radius)
		if not killer then return end

		mob:Provoke(killer)
		mob.Blackboard.CryAt = os.clock()
		mob.Blackboard.SpookedUntil = nil
	end
end

return Mourn
