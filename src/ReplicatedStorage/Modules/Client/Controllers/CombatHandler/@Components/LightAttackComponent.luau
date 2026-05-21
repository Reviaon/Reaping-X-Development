--@ Light Attack Component
local LightAttackComponent = {}

local _currentTrack = nil

function LightAttackComponent:Init(_controller)
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
		IsDiving = true 
	}) then
		return false
	end

	return true
end

function LightAttackComponent:Activate(controller, combatState)
	local Character = controller.Character
	if not Character then return end
	 
	local weaponId = combatState.ActiveWeapon or  controller.CombatConfig:ResolveWeaponId(controller)
	local weaponConfig = controller.CombatConfig:ResolveWeaponConfig(controller)

	if weaponId == "Unarmed" then
		return
	end

	local comboIndex = (combatState.ComboIndex % 10)

	if comboIndex == 0 then
		comboIndex = 1
	end

	local animationName = string.format("%s%d", weaponId, comboIndex)

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
	})

	controller.StatusService:SetStatus(
		Character, 
		"IsAttacking", 
		true, 
		weaponConfig.attack_duration or .2
	)

	controller.CooldownService:ApplyCooldown(
		Character,
		"IsAttacking",
		comboIndex >= weaponConfig.MaxCombo and weaponConfig.attack_cooldown_final 
			or weaponConfig.attack_cooldown or 0.3
	)
end

function LightAttackComponent:Deactivate(_controller, _combatState)
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return LightAttackComponent