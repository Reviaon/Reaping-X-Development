return function(mob)
	mob:SetTarget(nil)
	mob.Blackboard.Returning = true
	return true
end
