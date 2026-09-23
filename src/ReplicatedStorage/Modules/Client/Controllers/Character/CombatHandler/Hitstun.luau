--@ Hitstun
local CombatConfig = require(script.Parent.Config)

local Hitstun = {}

Hitstun.Settings = {
	Escape = 0.1, --@ Seconds the victim is free before the attacker's next hit can land
	Minimum = 0.3,
}

local function override(weaponConfig, comboIndex: number): number?
	local value = weaponConfig.hitstun

	if typeof(value) == "table" then
		value = value[comboIndex]
	end

	return typeof(value) == "number" and value or nil
end

--@ Nil on the final hit: the finisher's ragdoll owns that stun.
function Hitstun.Resolve(weaponId: string, comboIndex: number): number?
	local weaponConfig = CombatConfig.WeaponConfig[weaponId]
	if not weaponConfig then return nil end

	local current = CombatConfig:ResolveAttackTiming(nil, comboIndex, weaponConfig)
	if current.is_final then return nil end

	local authored = override(weaponConfig, comboIndex)
	if authored then return authored end

	local nextHit = CombatConfig:ResolveAttackTiming(nil, comboIndex + 1, weaponConfig)
	local gap = math.max(current.duration, current.cooldown) + nextHit.hitbox_delay - current.hitbox_delay

	return math.max(gap - Hitstun.Settings.Escape, Hitstun.Settings.Minimum)
end

return Hitstun
