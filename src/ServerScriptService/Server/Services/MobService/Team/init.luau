--[[@
	**Team**: how mobs work together, in two kinds of group
	- **Pack** (`Team.Join`, keyed by spawn group): packmates share targets, sightings and reach, and balance who hunts whom
	- **Fight** (`Team.Fight`, keyed by the target): every mob on one target, whatever its kind or pack
	  - Takes turns at the lead (`Slots`), hands the lead to the next in line, rings the target while waiting (`Orbit`)
	  - Holds one grab per key at a time (`Reservations`) and sends a waiting mob in when a member is hit (`BreakIns`)
	  - A mob's own `pack` settings decide how it plays its part; `pack = false` attacks freely but still rings and reserves
]]
local Config = require("@self/Config")
local Group = require("@self/Group")

local Pack = Group.Class({
	require("@self/Targets"),
	require("@self/Balance"),
	require("@self/Reach"),
	require("@self/Sightings"),
}, "pack")

local Fight = Group.Class({
	require("@self/Slots"),
	require("@self/BreakIns"),
	require("@self/Reservations"),
	require("@self/Orbit"),
}, "fight")

local packs = Group.Registry(Pack)
local fights = Group.Registry(Fight)

local Team = {}
Team.Settings = Config

function Pack:Leave(mob)
	packs.Leave(self, mob)
end

function Fight:Leave(mob)
	fights.Leave(self, mob)
end

function Team.Join(mob, key: any)
	local team = packs.Join(mob, key)
	mob.Team = team

	return team
end

function Team.Get(key: any)
	return packs.Get(key)
end

function Team.Fight(mob, target: Model?)
	local fight = mob.FightGroup

	if fight and fight.Key ~= target then
		mob.FightGroup = nil
		fight:Leave(mob)
		fight = nil
	end

	if target and not fight then
		fight = fights.Join(mob, target)
		mob.FightGroup = fight
	end

	return fight
end

function Team.FightOver(target: Model)
	return fights.Get(target)
end

return Team
