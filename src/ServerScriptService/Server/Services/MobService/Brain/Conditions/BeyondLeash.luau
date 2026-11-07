local Sight = require("../../Senses/Sight")

return function(mob, args)
	if mob:Provoker() then return false end

	local target = mob:GetTarget()
	local hunting = target ~= nil and Sight.Knows(mob, target)
	local range = if hunting then args.hunt or "hunt_range" else args.range or "leash_range"

	return mob:HomeDistance() > mob:Setting(range)
end
