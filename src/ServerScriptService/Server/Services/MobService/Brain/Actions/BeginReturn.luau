return function(mob)
	mob.Blackboard.Retreating = mob.Target ~= nil
	mob.Blackboard.Returning = true
	mob:SetTarget(nil)
	return true
end
