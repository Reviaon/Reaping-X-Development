return function(mob, args)
	if mob:Provoker() then return false end

	return mob:HomeDistance() > mob:Setting(args.range or "leash_range")
end
