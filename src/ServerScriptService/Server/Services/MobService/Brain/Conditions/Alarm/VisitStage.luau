return function(mob, args)
	local visit = mob.Blackboard.Visit
	return visit ~= nil and visit.Stage == args.stage
end
