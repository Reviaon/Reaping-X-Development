local Predators = require("../../Senses/Predators")

return function(mob, args)
	local settings = mob.Config.evade
	if not settings then return false end

	local blackboard = mob.Blackboard
	local key = args.within or (if mob.Machine.Name == "Evade" then "safe" else "range")
	local found = Predators.Near(mob, settings[key], settings.predators, if args.within then nil else settings.startle)

	if #found > 0 then
		blackboard.Predators = found
		return true
	end

	if not args.within and os.clock() < (blackboard.StartledUntil or 0) then
		local remembered = Predators.Alive(blackboard.Predators)
		blackboard.Predators = remembered
		return #remembered > 0
	end

	blackboard.Predators = nil

	return false
end
