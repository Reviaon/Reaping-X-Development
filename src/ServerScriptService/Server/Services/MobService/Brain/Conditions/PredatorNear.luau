local Predators = require("../../Senses/Predators")

return function(mob)
	local settings = mob.Config.evade
	if not settings then return false end

	local blackboard = mob.Blackboard
	local range = if mob.Machine.Name == "Evade" then settings.safe else settings.range
	local found = Predators.Near(mob, range, settings.predators, settings.startle)

	if #found > 0 then
		blackboard.Predators = found
		return true
	end

	if os.clock() < (blackboard.StartledUntil or 0) then
		local remembered = Predators.Alive(blackboard.Predators)
		blackboard.Predators = remembered
		return #remembered > 0
	end

	blackboard.Predators = nil

	return false
end
