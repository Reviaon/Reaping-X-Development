--@ Light Attack Component
local LightAttackComponent = {}

local _currentTrack = nil
local _impulseThread = nil

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
	local animationName = string.format("%s%s%d", weaponId, "Attack", comboIndex)

	local attack_duration = typeof(weaponConfig.attack_duration) == "table" 
		and weaponConfig.attack_duration[comboIndex] 
		or weaponConfig.attack_duration or 0.2

	local cooldown_duration = comboIndex >= weaponConfig.MaxCombo 
			and weaponConfig.attack_cooldown_final 
			or weaponConfig.attack_cooldown or 0.3

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action4,
		FadeTime = 0.1,
		Loop = false,
	})

	warn("Playing animation:", animationName)

	if weaponConfig.light_impulse then
		local impulse_delay = weaponConfig.light_impulse.impulse_delay 
			and weaponConfig.light_impulse.impulse_delay[comboIndex] or 0.2

		local impulseData = (weaponConfig.light_impulse.impulse and weaponConfig.light_impulse.impulse[comboIndex])
			or weaponConfig.light_impulse

		--@ Cancel any pending impulse before scheduling a new one
		if _impulseThread then
			task.cancel(_impulseThread)
			_impulseThread = nil
		end

		_impulseThread = task.delay(impulse_delay, function()
			_impulseThread = nil
			if not Character or not Character.Parent then return end
			local root = Character:FindFirstChild("HumanoidRootPart")

			if root then
				local trove = controller.PhysicsService.ApplyImpulse(controller, {
					direction = root.CFrame.LookVector,
					speed = impulseData.speed or 30,
					duration = impulseData.duration or 0.2,
					falloff = impulseData.falloff or 0.2,
					updateDirection = true,
				})

				if trove then
					controller:Set("_activeImpulseTrove", trove)
				end
			end
		end)

		controller:Set("_impulseThread", _impulseThread)
	end

	controller.StatusService:SetStatus(Character, "IsAttacking", true, attack_duration)
	controller.CooldownService:ApplyCooldown(Character, "IsAttacking", cooldown_duration)
end

function LightAttackComponent:Deactivate(_controller, _combatState)
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return LightAttackComponent