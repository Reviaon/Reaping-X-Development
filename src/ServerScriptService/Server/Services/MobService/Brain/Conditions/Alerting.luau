local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

return function(mob)
	local alert: MobTypes.Alert? = mob.Config.alert or nil
	if not alert then return false end

	local target = mob:GetTarget()
	local board = mob.Blackboard

	if not target or board.Alerted == target then return false end

	if os.clock() - (board.AlertedAt or -math.huge) < alert.cooldown then
		board.Alerted = target
		return false
	end

	return true
end
