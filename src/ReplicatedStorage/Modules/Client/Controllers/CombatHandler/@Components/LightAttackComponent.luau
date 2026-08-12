--@ Light Attack Component
local LightAttackComponent = {}

local RunService = game:GetService("RunService")

local EASE_OUT_DEFAULT = 0.1
local EASE_PAUSE_DEFAULT = 0.05
local EASE_FADE_DEFAULT = 0.15

local _currentTrack = nil
local _impulseThread = nil
local _easeThread = nil

local function cancelEaseOut()
	if _easeThread then
		task.cancel(_easeThread)
		_easeThread = nil
	end
end

--@ Decelerates the tail of an attack animation instead of letting it run out at
local function scheduleEaseOut(track, weaponConfig, attack_duration)
	cancelEaseOut()

	if not track then 
		return 
	end

	local ease_out = weaponConfig.ease_out or EASE_OUT_DEFAULT
	if ease_out <= 0 then return end

	ease_out = math.min(ease_out, attack_duration)

	local ease_pause = weaponConfig.ease_pause or EASE_PAUSE_DEFAULT
	local ease_fade = weaponConfig.ease_fade or EASE_FADE_DEFAULT
	local start_at = math.max(attack_duration - ease_out, 0)

	_easeThread = task.delay(start_at, function()
		_easeThread = nil

		if not (track and track.IsPlaying) then return end

		local began = os.clock()

		while track.IsPlaying do
			local alpha = math.clamp((os.clock() - began) / ease_out, 0, 1)
			track:AdjustSpeed(1 - alpha)

			if alpha >= 1 then break end

			RunService.Heartbeat:Wait()
		end

		if not track.IsPlaying then return end

		track:AdjustSpeed(0)

		if ease_pause > 0 then
			task.wait(ease_pause)
		end

		if track.IsPlaying then
			track:Stop(ease_fade)
		end
	end)
end

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

	local is_diving = controller.StatusService:CheckStatuses(Character, { IsDiving = true })

	local cooldown_duration = comboIndex >= weaponConfig.MaxCombo 
			and weaponConfig.attack_cooldown_final 
			or weaponConfig.attack_cooldown or 0.3

	cancelEaseOut()

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

	scheduleEaseOut(_currentTrack, weaponConfig, attack_duration)

	warn("Playing animation:", animationName)

	if weaponConfig.light_impulse and not is_diving then
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
					
					priority = impulseData.priority
						or weaponConfig.light_impulse.priority
						or 1,
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
	controller.StatusService:SetStatus(Character, "NoJump", true, 1)
end

function LightAttackComponent:Deactivate(_controller, _combatState)
	cancelEaseOut()

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return LightAttackComponent