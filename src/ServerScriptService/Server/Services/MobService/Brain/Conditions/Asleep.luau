local random = Random.new()

return function(mob)
	local blackboard = mob.Blackboard

	if blackboard.Sleeper == nil then
		local sleep = mob.Config.sleep
		local sleeper = sleep ~= false and sleep ~= nil and random:NextNumber() < sleep.chance

		blackboard.Sleeper = sleeper
		blackboard.Asleep = sleeper
	end

	return blackboard.Asleep == true
end
