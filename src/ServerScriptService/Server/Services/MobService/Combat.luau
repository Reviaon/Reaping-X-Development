local Jloader = require("@game/ReplicatedStorage/JLoader")

local Perception = require("./Perception")

local Combat = {}

local combatService = nil

local function service()
	combatService = combatService or Jloader.GetService("CombatService")
	return combatService
end

function Combat.Hit(mob, target: Model, attack): boolean
	local CombatService = service()
	local attacker = mob.Model

	if not CombatService:ApplyKnockback(attacker, target, nil, attack.reaction_weapon, attack.reaction_combo) then
		return false
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")

	if humanoid and attack.damage > 0 then
		humanoid:TakeDamage(attack.damage)
	end

	CombatService:BroadcastHit(attacker, target, attack.reaction_weapon, attack.reaction_combo)

	return true
end

function Combat.Strike(mob, attack): number
	local root = mob.Root
	local look = root.CFrame.LookVector
	local from = root.Position + look * (attack.reach_from or 0)
	local to = root.Position + look * attack.reach
	local hits = 0

	for _, target in Perception.PlayersAlong(from, to, attack.radius) do
		if Combat.Hit(mob, target, attack) then
			hits += 1
		end
	end

	return hits
end

return Combat
