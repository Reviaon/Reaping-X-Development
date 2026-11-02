local random = Random.new()

return function(mob)
	local dash = mob.Config.dash
	local flank = dash and dash.flank
	if not flank then return false end

	local blackboard = mob.Blackboard
	local now = os.clock()

	if now < (blackboard.FlankReadyAt or 0) then return false end

	local target = mob:GetTarget()
	local distance = mob:TargetDistance()

	if not target or not distance or distance > (flank.range or mob:Setting("attack_range") * 2) then return false end
	if not mob.Services.StatusService:IsGuardingFrom(target, mob.Root.Position) then return false end

	if random:NextNumber() > flank.chance then
		blackboard.FlankReadyAt = now + (flank.retry or 1)
		return false
	end

	return true
end
