local Combat = require("../../Combat")

return function(mob)
	local pounce = mob.Config.pounce
	if not pounce then return false end
	if os.clock() < (mob.Blackboard.NextPounceAt or 0) then return false end
	if Combat.Spec(mob, Combat.NextIndex(mob)).min_range then return false end

	local distance = mob:TargetDistance()

	return distance ~= nil and distance > mob:Setting("attack_range") and distance <= pounce.range
end
