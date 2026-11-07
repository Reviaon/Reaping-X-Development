local Jloader = require("@game/ReplicatedStorage/JLoader")

local Perception = require("../Senses/Perception")

local Attacks = {}

local combatService = nil
local effectService = nil

local function service()
	combatService = combatService or Jloader.GetService("CombatService")
	return combatService
end

local function effects()
	effectService = effectService or Jloader.GetService("EffectService")
	return effectService
end

function Attacks.Length(attack): number
	return math.max(#(attack.animations or {}), 1)
end

function Attacks.NextIndex(mob): number
	local attack = mob.Config.attack
	local blackboard = mob.Blackboard

	if not blackboard.LastAttackAt or os.clock() - blackboard.LastAttackAt > (attack.combo_reset or 0) then
		return 1
	end

	return (blackboard.Combo or 0) % Attacks.Length(attack) + 1
end

local function specAt(mob, index: number)
	local config = mob.Config
	local attack = config.attack
	local override = attack.combo and attack.combo[index]
	local spec = table.clone(attack)

	spec.index = index
	spec.range = config.attack_range
	spec.final = index == Attacks.Length(attack)
	spec.animation = attack.animations and attack.animations[index]

	if override then
		for key, value in override do
			spec[key] = value
		end
	end

	if spec.launch then
		local launch = table.clone(config.launch)

		if typeof(spec.launch) == "table" then
			for key, value in spec.launch do
				launch[key] = value
			end
		end

		spec.launch = launch
	end

	local speed = spec.speed or 1

	if speed ~= 1 then
		spec.windup /= speed
		spec.recovery /= speed
		spec.cooldown /= speed

		if spec.leap then
			local leap = table.clone(spec.leap)
			leap.delay = (leap.delay or 0) / speed
			leap.speed = leap.speed and leap.speed * speed
			spec.leap = leap
		end
	end

	return spec
end

function Attacks.StandOff(spec): number?
	if not spec.min_range then return nil end
	return (spec.min_range + spec.range) / 2
end

function Attacks.BackOffSpeed(mob, spec): number
	local config = mob.Config
	local backOff = spec.back_off

	return backOff and backOff.speed or config.pack and config.pack.retreat_speed or config.walk_speed
end

local function untilNext(mob, spec): number
	local nextSpec = specAt(mob, spec.index + 1)
	local backOff = 0

	if nextSpec.min_range then
		backOff = math.max(Attacks.StandOff(nextSpec) - spec.range, 0) / Attacks.BackOffSpeed(mob, nextSpec)
	end

	return spec.recovery + spec.cooldown + backOff + (spec.hitstun_slack or 0)
end

function Attacks.Spec(mob, index: number)
	local spec = specAt(mob, index)

	if spec.hitstun == nil and not spec.final then
		spec.hitstun = untilNext(mob, spec)
	end

	return spec
end

local function fill(base, override)
	local result = table.clone(base)

	for key, value in override do
		result[key] = value
	end

	return result
end

function Attacks.Ability(mob, name: string)
	local config = mob.Config
	local spec = fill(config.attack, config.abilities[name])

	spec.ability = name
	spec.index = nil
	spec.final = false
	spec.speed = config.abilities[name].speed

	if spec.launch then
		spec.launch = fill(config.launch, if typeof(spec.launch) == "table" then spec.launch else {})
	end

	return spec
end

function Attacks.Grab(mob, target: Model, spec): boolean
	local CombatService = service()
	local attacker = mob.Model
	local downed = spec.targets_ragdolled == true and Jloader.GlobalFunctions.RagdollService.IsRagdolled(target)

	if downed then
		if not Jloader.GlobalFunctions.StatusService:IsAlive(target) then return false end
	elseif not CombatService:CanHit(attacker, target) then
		return false
	end

	local scene = Jloader.GlobalFunctions.PairSceneService:Begin(spec.cinematic, attacker, target)

	if scene then
		CombatService.Provoked:Fire(attacker, target)
		Attacks.Shot(mob, spec.visual)
	end

	return scene ~= nil
end

function Attacks.Hit(mob, target: Model, spec): boolean
	if spec.cinematic then
		return Attacks.Grab(mob, target, spec)
	end

	local CombatService = service()
	local attacker = mob.Model
	local landed

	if spec.launch then
		landed = CombatService:ApplyLaunch(attacker, target, spec.launch)
	else
		landed = CombatService:ApplyKnockback(attacker, target, nil, spec.reaction_weapon, spec.reaction_combo, spec.hitstun)
	end

	if not landed then return false end

	local humanoid = target:FindFirstChildOfClass("Humanoid")

	if humanoid and spec.damage > 0 then
		humanoid:TakeDamage(spec.damage)
	end

	CombatService:BroadcastHit(attacker, target, spec.reaction_weapon, spec.reaction_combo)

	return true
end

function Attacks.Visual(mob, spec)
	local path = mob.Config.visuals
	if not path or not spec.index then return end

	effects():SpawnVisual(nil, {
		Effect = path,
		Method = "Attack",
		Info = { Character = mob.Model, ComboIndex = spec.index, Speed = spec.speed or 1 },
	})
end

function Attacks.Shot(mob, name: string?, speed: number?)
	local path = mob.Config.visuals
	if not path or not name then return end

	effects():SpawnVisual(nil, {
		Effect = path,
		Method = name,
		Info = { Character = mob.Model, Shot = name, Speed = speed or 1 },
	})
end

function Attacks.Press(mob, spec)
	local target = mob:GetTarget()

	if not spec.index or spec.index <= 1 or not target then return end
	if target:GetAttribute("IsStunned") ~= true then return end

	service():Stun(target, spec.windup + (spec.hitstun_slack or 0))
end

function Attacks.Strike(mob, spec): number
	local root = mob.Root
	local look = root.CFrame.LookVector
	local from = root.Position + look * (spec.reach_from or 0)
	local to = root.Position + look * spec.reach
	local hits = 0

	for _, target in Perception.PlayersAlong(from, to, spec.radius) do
		if Attacks.Hit(mob, target, spec) then
			hits += 1
		end
	end

	return hits
end

return Attacks
