local Combat = require("../../Combat")

return function(mob)
	local distance = mob:TargetDistance()
	if not distance then return false end

	local spec = Combat.Spec(mob, Combat.NextIndex(mob))

	return distance <= spec.range and distance >= (spec.min_range or 0)
end
