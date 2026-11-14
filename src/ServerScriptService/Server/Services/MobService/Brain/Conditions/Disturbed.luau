local Predators = require("../../Senses/Predators")

return function(mob)
	local sleep = mob.Config.sleep
	if not sleep then return false end

	local evade = mob.Config.evade
	local found = Predators.Near(mob, sleep.wake_range, evade and evade.predators, math.huge)
	if #found == 0 then return false end

	mob.Blackboard.Predators = found

	return true
end
