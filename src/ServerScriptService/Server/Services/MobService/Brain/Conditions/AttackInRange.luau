local Attacks = require("../../Combat/Attacks")

return function(mob)
	local distance = mob:TargetDistance()
	if not distance then return false end

	local spec = Attacks.Spec(mob, Attacks.NextIndex(mob))

	return distance <= spec.range and distance >= (spec.min_range or 0)
end
