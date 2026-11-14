local Predators = require("../../Senses/Predators")

local random = Random.new()

return function(mob)
	local settings = mob.Config.evade
	if not settings or not settings.watch then return false end

	local blackboard = mob.Blackboard
	local found = Predators.Near(mob, settings.watch, settings.predators)

	if #found == 0 then
		blackboard.WatchUntil = nil
		return false
	end

	local now = os.clock()
	local span = settings.watch_time

	if not blackboard.WatchUntil then
		blackboard.WatchUntil = now + random:NextNumber(span[1], span[2])
	end

	if now >= blackboard.WatchUntil then return false end

	blackboard.Predators = found

	return true
end
