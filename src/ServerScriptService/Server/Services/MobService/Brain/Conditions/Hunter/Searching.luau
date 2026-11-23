return function(mob)
	local search = mob.Blackboard.Search
	if not search then return false end

	if os.clock() >= search.Until or not mob.Config.search then
		mob.Blackboard.Search = nil
		return false
	end

	return true
end
