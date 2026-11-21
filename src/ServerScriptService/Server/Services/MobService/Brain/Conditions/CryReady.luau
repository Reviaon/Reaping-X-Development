return function(mob)
	if not mob.Config.cry or not mob:GetTarget() then return false end

	return os.clock() >= (mob.Blackboard.CryAt or 0)
end
