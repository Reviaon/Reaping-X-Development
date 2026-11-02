local random = Random.new()

local HELD = { InPairScene = true }
local RAGDOLLED = "IsRagdolled"

local function usable(mob, ability): boolean
	local users = ability.users
	if not users then return true end

	local team = mob.Team
	local fresh = users.fresh and os.clock() - (mob.Blackboard.AggroAt or -math.huge) <= users.fresh
	local passive = users.passive and team ~= nil and not team:IsAttacker(mob)

	return fresh or passive or false
end

local function open(mob, ability): (boolean, boolean)
	local target = mob:GetTarget()
	if not target then return false, false end

	local services = mob.Services
	if services.StatusService:CheckStatuses(target, HELD) or services.PairSceneService.IsCarried(target) then return false, false end

	local downed = target:GetAttribute(RAGDOLLED) == true

	return not downed or ability.targets_ragdolled == true, downed
end

local function ready(mob, name: string, ability): boolean
	local blackboard = mob.Blackboard
	local readyAt = blackboard.AbilityReadyAt or {}
	blackboard.AbilityReadyAt = readyAt

	local now = os.clock()
	if now < (readyAt[name] or 0) then return false end

	local distance = mob:TargetDistance()
	if not distance or distance > ability.range or distance < (ability.min_range or 0) then return false end
	if not usable(mob, ability) then return false end

	local targetable, downed = open(mob, ability)
	if not targetable then return false end

	local key = ability.reserve or name
	if mob.Team and mob.Team:Reserved(mob.Target, key) then return false end

	local chance = if downed and ability.ragdolled_chance then ability.ragdolled_chance else ability.chance

	if chance and random:NextNumber() > chance then
		readyAt[name] = now + (ability.retry or 1.5)
		return false
	end

	return true
end

return function(mob)
	local abilities = mob.Config.abilities
	if not abilities then return false end

	for name, ability in abilities do
		if ready(mob, name, ability) then
			mob.Blackboard.PendingAbility = name
			return true
		end
	end

	return false
end
