local HELD = { InPairScene = true }

return function(mob)
	if not mob.Config.lurk then return false end

	local target = mob:GetTarget()
	if not target then return false end

	local statuses = mob.Services.StatusService
	return statuses:CheckStatuses(target, HELD) and not statuses:CheckStatuses(mob.Model, HELD)
end
