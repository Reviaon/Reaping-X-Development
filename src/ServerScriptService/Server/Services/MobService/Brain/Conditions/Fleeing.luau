return function(mob)
	return os.clock() < (mob.Blackboard.FleeUntil or 0)
end
