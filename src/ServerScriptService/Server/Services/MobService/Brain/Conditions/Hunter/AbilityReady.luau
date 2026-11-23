local Tempo = require("../../../Combat/Tempo")

local random = Random.new()

local HELD = { InPairScene = true }
local RECOVERING = { IsRecovering = true }
local RAGDOLLED = "IsRagdolled"
local FLAT = Vector3.new(1, 0, 1)

local function usable(mob, ability): boolean
	local users = ability.users
	if not users then return true end

	local team = mob:Fight()
	local fresh = users.fresh and os.clock() - (mob.Blackboard.AggroAt or -math.huge) <= users.fresh
	local passive = users.passive and team ~= nil and not team:IsAttacker(mob)

	return fresh or passive or false
end

local function faced(mob, ability): boolean
	local angle = ability.faced
	if not angle then return true end

	local root = mob:TargetRoot()
	if not root then return false end

	local toward = (mob.Root.Position - root.Position) * FLAT
	local look = root.CFrame.LookVector * FLAT
	if toward.Magnitude < 1e-3 or look.Magnitude < 1e-3 then return true end

	return look.Unit:Dot(toward.Unit) >= math.cos(math.rad(angle))
end

local function open(mob, ability): (boolean, boolean)
	local target = mob:GetTarget()
	if not target then return false, false end

	local services = mob.Services
	if services.StatusService:CheckStatuses(target, HELD) or services.PairSceneService.IsCarried(target) then return false, false end

	if target:GetAttribute(RAGDOLLED) == true then
		return ability.targets_ragdolled == true, true
	end

	return not services.StatusService:CheckStatuses(target, RECOVERING), false
end

local function ready(mob, name: string, ability): boolean
	local blackboard = mob.Blackboard
	local readyAt = blackboard.AbilityReadyAt or {}
	blackboard.AbilityReadyAt = readyAt

	local now = os.clock()
	if now < (readyAt[name] or 0) then return false end
	if ability.posture and (ability.posture == "stance") ~= (blackboard.Stanced == true) then return false end

	local distance = mob:TargetDistance()
	if not distance or distance > ability.range or distance < (ability.min_range or 0) then return false end
	if not usable(mob, ability) then return false end
	if not faced(mob, ability) then return false end

	local targetable, downed = open(mob, ability)
	if not targetable then return false end

	local key = ability.reserve or name
	local fight = mob:Fight()
	if fight and fight:Reserved(mob.Target, key) then return false end

	local chance = if downed and ability.ragdolled_chance then ability.ragdolled_chance else ability.chance

	if Tempo.SetUp(mob, name) then
		chance = nil
	end

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
		if ability.follow_up then continue end

		if ready(mob, name, ability) then
			mob.Blackboard.PendingAbility = name
			return true
		end
	end

	return false
end
