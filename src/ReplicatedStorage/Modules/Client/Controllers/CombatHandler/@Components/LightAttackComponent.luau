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

	local comboIndex = combatState.ComboIndex
	local animationName = string.format("%s%d", weaponId, comboIndex)

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
		Loop = false,
	})

	warn("Playing animation:", animationName)

	if weaponConfig.light_impulse then
		local impulse_delay = weaponConfig.light_impulse.impulse_delay 
			and weaponConfig.light_impulse.impulse_delay[comboIndex] or 0.2

		task.delay(impulse_delay, function()
			if not Character or not Character.Parent then return end
			local root = Character:FindFirstChild("HumanoidRootPart")

			if root then
				controller.PhysicsService.ApplyImpulse(controller, {
					direction = root.CFrame.LookVector,
					speed = weaponConfig.light_impulse.speed or 30,
					duration = weaponConfig.light_impulse.duration or 0.2,
					falloff = weaponConfig.light_impulse.falloff or 0.2,
				})
			end
		end)
	end

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