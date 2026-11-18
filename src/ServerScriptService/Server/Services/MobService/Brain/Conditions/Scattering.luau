return function(mob)
	if mob.Blackboard.Scatter ~= true then return false end

	if not mob.Config.dash or not mob.Config.gnaw or not mob:TargetRoot() then
		mob.Blackboard.Scatter = nil
		return false
	end

	return true
end
