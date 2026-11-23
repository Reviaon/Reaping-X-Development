return function(mob)
	return os.clock() >= (mob.Blackboard.NextAttackAt or 0)
end
