return function(mob, args)
	local distance = mob:TargetDistance()
	return distance ~= nil and distance <= mob:Setting(args.range)
end
