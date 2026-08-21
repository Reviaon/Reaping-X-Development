--@ Light Attack Component
local LightAttackComponent = {}
local RunService = game:GetService("RunService")

local _currentTrack = nil
local _impulseThread = nil
local _easeThread = nil

local function cancelEaseOut()
	if _easeThread then
		task.cancel(_easeThread)
		_easeThread = nil
	end
end

--@ Decelerates the tail of an attack animation instead of letting it run out at full
local function scheduleEaseOut(track, timing)
	cancelEaseOut()

	if not track then 
		return 
	end

	local speed = timing.speed
	local ease_out = math.min(timing.ease_out, timing.duration)
	if ease_out <= 0 then return end

	local ease_pause = timing.ease_pause
	local ease_fade = timing.ease_fade
	local start_at = math.max(timing.duration - ease_out, 0)

	_easeThread = task.delay(start_at, function()
		_easeThread = nil

		if not (track and track.IsPlaying) then return end

		local began = os.clock()

		while track.IsPlaying do
			local alpha = math.clamp((os.clock() - began) / ease_out, 0, 1)
			track:AdjustSpeed(speed * (1 - alpha))

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

--@ Broadcasts this hit's weapon visual. Nothing renders here - the request round-trips
--@ through the server so every client, the attacker included, plays the same sequence.
local function broadcastVisual(controller, weaponId, comboIndex, speed)
	local path = controller.CombatConfig:ResolveWeaponVisuals(weaponId)
	if not path then return end

	local relay = controller.VisualRelay
	if not relay then return end

	relay.CreateVisual:Fire("SpawnVisual", {
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
	 
	local weaponId = combatState.ActiveWeapon or  controller.CombatConfig:ResolveWeaponId(controller)
	local weaponConfig = controller.CombatConfig:ResolveWeaponConfig(controller)

	if weaponId == "Unarmed" then
		return
	end

	local comboIndex = combatState.ComboIndex
	local animationName = string.format("%s%s%d", weaponId, "Attack", comboIndex)

	--@ One resolve per swing: the playback speed plus every timing already scaled by it.
	local timing = controller.CombatConfig:ResolveAttackTiming(controller, comboIndex, weaponConfig)

	local is_diving = controller.StatusService:CheckStatuses(Character, { IsDiving = true })

	cancelEaseOut()

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = timing.speed,
		Priority = Enum.AnimationPriority.Action4,
		FadeTime = 0.1,
		Loop = false,
	})

	scheduleEaseOut(_currentTrack, timing)

	warn("Playing animation:", animationName, "at", timing.speed .. "x")

	broadcastVisual(controller, weaponId, comboIndex, timing.speed)

	if timing.impulse and not is_diving then
		local impulse_delay = timing.impulse_delay
		local impulseData = timing.impulse

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
					--@ Already scaled by attack_speed; the fallbacks these used to inline now
					--@ live in Config so an unauthored impulse gets retimed as well.
					speed = impulseData.speed,
					duration = impulseData.duration,
					falloff = impulseData.falloff,
					updateDirection = true,

					--@ Held WASD stays folded into the lunge instead of the push owning the
					--@ character outright - see PhysicsService.ApplyImpulse.
					influence = impulseData.influence,

					priority = timing.impulse_priority,
				})

				if trove then
					controller:Set("_activeImpulseTrove", trove)
				end
			end
		end)

		controller:Set("_impulseThread", _impulseThread)
	end

	controller.StatusService:SetStatus(Character, "IsAttacking", true, timing.duration)
	controller.CooldownService:ApplyCooldown(Character, "IsAttacking", timing.cooldown)
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