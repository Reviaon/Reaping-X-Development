local Attacks = require("../../Combat/Attacks")

local random = Random.new()

return function(mob)
	local pounce = mob.Config.pounce
	if not pounce then return false end

	local now = os.clock()
	if now < (mob.Blackboard.NextPounceAt or 0) then return false end
	if Attacks.Spec(mob, Attacks.NextIndex(mob)).min_range then return false end

	local distance = mob:TargetDistance()
	if distance == nil or distance <= math.max(mob:Setting("attack_range"), pounce.min_range or 0) or distance > pounce.range then return false end

	if pounce.chance and random:NextNumber() > pounce.chance then
		mob.Blackboard.NextPounceAt = now + (pounce.retry or 1)
		return false
	end

	return true
end
