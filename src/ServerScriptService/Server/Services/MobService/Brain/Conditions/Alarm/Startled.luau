local Perception = require("../../../Senses/Perception")

return function(mob)
	local board = mob.Blackboard
	if os.clock() >= (board.SpookedUntil or 0) then return false end

	return Perception.IsValidTarget(board.Spooker)
end
