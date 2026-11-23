local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../../../Senses/Perception")
local Sight = require("../../../Senses/Sight")

local LEAVE_SCALE = 1.5

local random = Random.new()

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2] or range[1])
end

local function finish(mob, greet: MobTypes.Greet)
	local board = mob.Blackboard

	board.Visit = nil
	board.Companion = nil
	board.VisitReadyAt = os.clock() + roll(greet.cooldown)
end

return function(mob)
	local greet: MobTypes.Greet? = mob.Config.greet or nil
	if not greet then return false end

	local board = mob.Blackboard
	local visit = board.Visit
	local now = os.clock()

	if visit then
		local root = Perception.RootOf(visit.Player)
		local gone = not root or not Perception.IsValidTarget(visit.Player) or (root.Position - mob.Root.Position).Magnitude > greet.range * LEAVE_SCALE

		if gone or now >= visit.Until or (visit.Stage == "follow" and now >= visit.StageUntil) then
			finish(mob, greet)
			return false
		end

		if visit.Stage == "circle" and now >= visit.StageUntil then
			visit.Stage = "greet"
		end

		return true
	end

	if now < (board.VisitReadyAt or 0) then return false end

	local player = Sight.Noticed(mob, greet.range)[1]
	if not player then return false end

	board.Companion = player
	board.Visit = {
		Player = player,
		Stage = "circle",
		StageUntil = now + roll(greet.circle),
		Until = now + greet.give_up,
	}

	return true
end
