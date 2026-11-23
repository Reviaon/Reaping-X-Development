return function(mob, args)
	local stance = mob.Config.stance
	if not stance then return false end

	local stanced = mob.Blackboard.Stanced == true
	local distance = if mob.Target then mob:TargetDistance() else nil

	if args.exit then
		return stanced and (not distance or distance > stance.leave)
	end

	return not stanced and distance ~= nil and distance <= stance.range
end
