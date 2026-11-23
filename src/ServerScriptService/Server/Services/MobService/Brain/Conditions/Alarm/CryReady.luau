return function(mob)
	if not mob.Config.cry or not mob:GetTarget() then return false end

	local board = mob.Blackboard
	local fresh = board.CriedAt == nil or (board.AggroAt or 0) > board.CriedAt

	return fresh or os.clock() >= (board.CryAt or 0)
end
