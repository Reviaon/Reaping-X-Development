return function(mob)
	local sleep = mob.Config.sleep
	local blackboard = mob.Blackboard

	if not sleep or not sleep.resettle or not blackboard.Sleeper then return false end
	if mob:Provoker() then return false end

	local stirred = math.max(blackboard.EvadedAt or 0, blackboard.StartledUntil or 0, mob.HurtAt or 0)

	return os.clock() - stirred >= sleep.resettle
end
