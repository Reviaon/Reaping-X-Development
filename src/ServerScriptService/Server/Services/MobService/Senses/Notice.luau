--[[@
	**Notice**: the mark over a mob's head when a player catches its attention
	- **Notice** (`notice`): the moment it notices a player, by sight or by hearing (aggro, or prey startled by one)
	- **Confuse** (`confuse`): while it's idle, a player is within `range` but unnoticed, out of sight and beyond `sight.hear_range`
	  - Checked every think; skipped while it or its pack has a target, or it evades, watches, sleeps or is disabled
	  - Skipped when anyone in range is noticed, and for `cooldown` seconds after a notice, so `?` never follows `!`
	- **Both** relay `Combat.Notice` to every client with the config's `visual`
	  - Each mark's `emit` Attachment plays only for that mark: the other marks' are dropped, every other attachment always plays
	  - A new mark is a config key in `MARKS`
]]
local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Perception = require("./Perception")
local Sight = require("./Sight")

local EFFECT = "Combat.Notice"
local METHOD = "Emit"
local MARKS = { "notice", "confuse" }

local Notice = {}

local effectService = nil

local function effects()
	effectService = effectService or Jloader.GetService("EffectService")
	return effectService
end

local function others(mob, settings: MobTypes.Notice): { string }
	local names = {}

	for _, key in MARKS do
		local mark: MobTypes.Notice? = mob.Config[key]

		if mark and mark.emit and mark.emit ~= settings.emit then
			table.insert(names, mark.emit)
		end
	end

	return names
end

local function emit(mob, settings: MobTypes.Notice)
	effects():SpawnVisual(nil, {
		Effect = EFFECT,
		Method = METHOD,
		Info = {
			Character = mob.Model,
			Visual = settings.visual,
			Drop = others(mob, settings),
			Head = settings.head,
			Offset = settings.offset,
			Lifetime = settings.lifetime,
		},
	})
end

local function since(at: number?, now: number): number
	return now - (at or -math.huge)
end

function Notice.Show(mob, target: Model?): boolean
	local settings: MobTypes.Notice? = mob.Config.notice
	if not settings or not target or not Players:GetPlayerFromCharacter(target) then return false end

	local now = os.clock()
	local blackboard = mob.Blackboard

	if since(blackboard.NoticedAt, now) < settings.cooldown then return false end

	blackboard.NoticedAt = now
	emit(mob, settings)

	return true
end

local function idle(mob, now: number): boolean
	local blackboard = mob.Blackboard

	if mob.Target or blackboard.Asleep or mob:IsDisabled() then return false end
	if mob.Team and next(mob.Team.Engaged) ~= nil then return false end
	if blackboard.Predators and #blackboard.Predators > 0 then return false end
	if blackboard.WatchUntil and blackboard.WatchUntil > now then return false end

	return true
end

function Notice.Confuse(mob): boolean
	local settings: MobTypes.Confuse? = mob.Config.confuse
	if not settings or mob.Dead or not mob.Root then return false end

	local now = os.clock()
	local blackboard = mob.Blackboard

	if since(blackboard.ConfusedAt, now) < settings.cooldown then return false end
	if since(blackboard.NoticedAt, now) < settings.cooldown then return false end
	if not idle(mob, now) then return false end

	local hidden = false

	for _, player in Perception.PlayersNear(mob.Root.Position, settings.range) do
		if Sight.Notices(mob, player) then return false end

		hidden = true
	end

	if not hidden then return false end

	blackboard.ConfusedAt = now
	emit(mob, settings)

	return true
end

return Notice
