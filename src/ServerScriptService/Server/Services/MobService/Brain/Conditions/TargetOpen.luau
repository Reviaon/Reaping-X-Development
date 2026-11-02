local HELD = { InPairScene = true, IsRagdolled = true }

return function(mob)
	local target = mob:GetTarget()
	return target ~= nil and not mob.Services.StatusService:CheckStatuses(target, HELD)
end
