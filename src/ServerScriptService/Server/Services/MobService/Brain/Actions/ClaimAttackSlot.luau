return function(mob)
	local team = mob:Fight()
	if not team then return true end

	local root = mob:TargetRoot()
	if not root then return false end

	return team:ClaimSlot(mob, root.Position)
end
