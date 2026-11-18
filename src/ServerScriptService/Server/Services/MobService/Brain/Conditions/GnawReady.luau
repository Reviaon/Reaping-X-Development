local Jloader = require("@game/ReplicatedStorage/JLoader")

local HELD = { InPairScene = true }

local function gnawers(mob, target: Model): number
	local team = mob:Fight()
	if not team then return 0 end

	local count = 0

	for member in team.Members do
		if member ~= mob and not member.Dead and member.Blackboard.Gnawing == target then
			count += 1
		end
	end

	return count
end

return function(mob)
	local gnaw = mob.Config.gnaw
	if not gnaw then return false end

	local target = mob:GetTarget()
	if not target then return false end

	local RagdollService = Jloader.GlobalFunctions.RagdollService
	if not RagdollService.IsRagdolled(target) then return false end

	local services = mob.Services
	if services.StatusService:CheckStatuses(target, HELD) or services.PairSceneService.IsCarried(target) then return false end

	if mob.Blackboard.Gnawing == target then return true end

	local left = services.StatusService:GetRemainingTime(target, RagdollService.Settings.Status) or 0
	if left < gnaw.remaining then return false end

	return gnawers(mob, target) < gnaw.gnawers
end
