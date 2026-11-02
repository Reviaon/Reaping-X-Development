return function(mob)
	local rally = mob.Config.rally
	if not rally or mob.Blackboard.Rallied or not mob:GetTarget() then return false end

	local humanoid = mob.Humanoid

	return humanoid.Health > 0 and humanoid.Health <= humanoid.MaxHealth * rally.health
end
