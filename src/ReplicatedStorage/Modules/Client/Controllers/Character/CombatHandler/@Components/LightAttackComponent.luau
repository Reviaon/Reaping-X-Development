local LightAttackComponent = {}

local SWING = "LightAttack"

local function broadcastVisual(controller, weaponId, comboIndex, speed)
	local path = controller.CombatConfig:ResolveWeaponVisuals(weaponId)
	if not path then return end

	controller.AttackService:Broadcast(controller, {
		Effect = path,
		Method = "Attack",
		Info = {
			Character = controller.Character,
			ComboIndex = comboIndex,
			Speed = speed,
			WeaponId = weaponId,
		},
	})
end

function LightAttackComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then return false end

	if controller.CooldownService:CheckCooldown(Character, "IsAttacking") then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, {
		IsStunned = true,
		IsBlocking = true,
	}) then
		return false
	end

	return true
end

function LightAttackComponent:Activate(controller, combatState)
	local Character = controller.Character
	if not Character then return end

	local weaponId = combatState.ActiveWeapon or controller.CombatConfig:ResolveWeaponId(controller)
	local weaponConfig = controller.CombatConfig:ResolveWeaponConfig(controller)

	if weaponId == "Unarmed" then
		return
	end

	local comboIndex = combatState.ComboIndex
	local animationName = string.format("%s%s%d", weaponId, "Attack", comboIndex)

	local timing = controller.CombatConfig:ResolveAttackTiming(controller, comboIndex, weaponConfig)
	local is_diving = controller.StatusService:CheckStatuses(Character, { IsDiving = true })

	local AttackService = controller.AttackService

	local track = AttackService:SwapTrack(controller, SWING, Character, animationName, {
		Speed = timing.speed,
		Priority = Enum.AnimationPriority.Action4,
		FadeTime = 0.1,
		Loop = false,
	})

	AttackService:ScheduleEaseOut(controller, SWING, track, timing)
	broadcastVisual(controller, weaponId, comboIndex, timing.speed)
	AttackService:ScheduleHitbox(controller, SWING, Character, timing, { weaponId = weaponId })

	if not is_diving then
		AttackService:ScheduleImpulse(controller, SWING, Character, timing)
	end

	controller.StatusService:SetStatus(Character, "IsAttacking", true, timing.duration)
	controller.CooldownService:ApplyCooldown(Character, "IsAttacking", timing.cooldown)
	controller.StatusService:SetStatus(Character, "NoJump", true, 1)
end

function LightAttackComponent:Deactivate(controller, _combatState)
	controller.AttackService:CancelSwing(controller, SWING)
end

return LightAttackComponent
