return function(mob)
	local dash = mob.Config.dash

	return dash ~= nil and dash ~= false and dash.regroup == true and mob.Blackboard.Staggered == true and mob:TargetRoot() ~= nil
end
