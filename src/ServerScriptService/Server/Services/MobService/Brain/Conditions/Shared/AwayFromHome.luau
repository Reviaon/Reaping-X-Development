return function(mob, args)
	return mob:HomeDistance() > mob:Setting(args.range or "leash_range")
end
