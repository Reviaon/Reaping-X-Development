local AttackService = {}

local Settings = {
	TrackFade = 0.15, --@ Crossfade when one track replaces another, seconds
	HitEffectPath = "Combat.Hit", --@ ClientEffects path for the impact effect
	HitEffectMethod = "Emit",
	RelayKey = "VisualRelay", --@ Controller key holding the EffectService relay
	CombatRelayKey = "CombatRelay", --@ Controller key holding the CombatService relay
	LivingPath = { "World", "Live" }, --@ Workspace folder holding characters a hitbox may catch
}

AttackService.Settings = Settings

local _scopes = setmetatable({}, { __mode = "k" })

local _localEffects = nil

local function localEffects()
	if _localEffects then return _localEffects end
	if not game:GetService("RunService"):IsClient() then return nil end

	local first = game:GetService("ReplicatedFirst")
	local modules = first:FindFirstChild("Modules")
	local module = modules and modules:FindFirstChild("ClientEffects")

	if not module then return nil end

	local ok, handler = pcall(require, module)
	if not ok then return nil end

	_localEffects = handler
	return _localEffects
end

local function part(key, name)
	return key .. "/" .. name
end

function AttackService:Scope(controller)
	local scope = _scopes[controller]

	if not scope then
		scope = { threads = {}, tracks = {}, hitboxes = {} }
		_scopes[controller] = scope
	end

	return scope
end

function AttackService:Cancel(controller, key)
	local scope = self:Scope(controller)
	local thread = scope.threads[key]

	if thread then
		task.cancel(thread)
		scope.threads[key] = nil
	end
end

function AttackService:Schedule(controller, key, delay_for, callback)
	self:Cancel(controller, key)

	local scope = self:Scope(controller)

	scope.threads[key] = task.delay(delay_for, function()
		scope.threads[key] = nil
		callback()
	end)

	return scope.threads[key]
end

function AttackService:GetTrack(controller, key)
	return self:Scope(controller).tracks[key]
end

function AttackService:StopTrack(controller, key, fade)
	local scope = self:Scope(controller)
	local track = scope.tracks[key]

	if track then
		track:Stop(fade or Settings.TrackFade)
		scope.tracks[key] = nil
	end
end

function AttackService:SwapTrack(controller, key, character, animationName, properties)
	self:StopTrack(controller, key)

	if not character then return nil end

	local track = controller.AnimatorService:PlayTrack(character, animationName, properties)
	self:Scope(controller).tracks[key] = track

	return track
end

function AttackService:Broadcast(controller, payload)
	local relay = controller[Settings.RelayKey]
	if not relay then return false end

	relay.CreateVisual:Fire("SpawnVisual", payload)
	return true
end

function AttackService:PlayLocal(payload)
	local effects = localEffects()
	if not effects then return false end

	effects:Fire(payload)
	return true
end

function AttackService:BroadcastHit(controller, character, victim, effect, weaponId, comboIndex)
	local payload = {
		Effect = Settings.HitEffectPath,
		Method = Settings.HitEffectMethod,
		SkipSender = true,
		Info = {
			Target = victim,
			Attacker = character,
			Effect = effect,
			WeaponId = weaponId,
			ComboIndex = comboIndex,
		},
	}

	self:PlayLocal(payload)
	return self:Broadcast(controller, payload)
end

function AttackService:ReportHit(controller, victim, weaponId, comboIndex)
	local relay = controller[Settings.CombatRelayKey]
	if not relay then return false end

	local character = controller.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local attackerRoot = root and controller.PositionService.Pack(root.CFrame) or nil

	relay.ReportHit:Fire(victim, weaponId, comboIndex, attackerRoot)
	return true
end

function AttackService:LivingFolder()
	local found = workspace

	for _, segment in Settings.LivingPath do
		found = found:FindFirstChild(segment)
		if not found then return nil end
	end

	return found
end

function AttackService:ScheduleEaseOut(controller, key, track, timing)
	key = part(key, "ease")
	self:Cancel(controller, key)

	if not track then return end

	local ease_out = math.min(timing.ease_out, timing.duration)
	if ease_out <= 0 then return end

	local RunService = game:GetService("RunService")
	local speed = timing.speed
	local start_at = math.max(timing.duration - ease_out, 0)

	self:Schedule(controller, key, start_at, function()
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

		if timing.ease_pause > 0 then
			task.wait(timing.ease_pause)
		end

		if track.IsPlaying then
			track:Stop(timing.ease_fade)
		end
	end)
end

function AttackService:ScheduleImpulse(controller, key, character, timing)
	key = part(key, "impulse")
	self:Cancel(controller, key)

	local impulse = timing.impulse
	if not impulse then return end

	self:Schedule(controller, key, timing.impulse_delay, function()
		if not character or not character.Parent then return end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		controller.KnockbackService.Lunge(character, root.CFrame.LookVector, {
			speed = impulse.speed,
			duration = impulse.duration,
			falloff = impulse.falloff,
			rampIn = impulse.rampIn,
			distance = impulse.distance,
			influence = impulse.influence,
			priority = timing.impulse_priority,
		})
	end)
end

function AttackService:CancelHitbox(controller, key)
	key = part(key, "hitbox")
	self:Cancel(controller, key)

	local scope = self:Scope(controller)
	local handle = scope.hitboxes[key]

	if handle then
		if not handle.Disposed then
			handle:Dispose()
		end
		scope.hitboxes[key] = nil
	end
end

function AttackService:ScheduleHitbox(controller, key, character, timing, options)
	self:CancelHitbox(controller, key)

	key = part(key, "hitbox")
	options = options or {}

	local hitbox = timing.hitbox
	if not hitbox or hitbox.enabled == false then return end

	local living = self:LivingFolder()
	if not living then
		warn("[AttackService] workspace.World.Live is missing, so no hitbox was spawned.")
		return
	end

	self:Schedule(controller, key, timing.hitbox_delay, function()
		if not character or not character.Parent then return end

		local data = controller.CombatConfig:BuildHitboxData(hitbox)
		data.Attacker = character
		data.Debug = controller.DebugService.IsEnabled()

		local handle = controller.HitboxService.New(hitbox.shape, data, { living }, { character })

		self:Scope(controller).hitboxes[key] = handle
		controller:Set("_activeHitbox", handle)

		local hits = {}

		handle.onHit:Connect(function(target)
			controller:Set("_lastHitTarget", target)
			table.insert(hits, target)

			self:BroadcastHit(controller, character, target, hitbox.effect, options.weaponId, timing.combo_index)
			self:ReportHit(controller, target, options.weaponId, timing.combo_index)

			if options.onHit then
				options.onHit(target)
			end
		end)

		task.delay(hitbox.duration, function()
			if handle and not handle.Disposed then
				handle:Dispose()
			end

			local scope = self:Scope(controller)
			if scope.hitboxes[key] == handle then
				scope.hitboxes[key] = nil
			end

			if handle._data and handle._data.Debug then
				local label = string.format("[Hitbox] %s combo %d", tostring(options.weaponId), timing.combo_index)

				if #hits == 0 then
					warn(label .. " -> no targets")
				else
					local names = {}
					for _, target in hits do
						table.insert(names, target.Name)
					end
					warn(string.format("%s -> %d: %s", label, #hits, table.concat(names, ", ")))
				end
			end
		end)
	end)
end

function AttackService:CancelSwing(controller, key, fade)
	self:Cancel(controller, part(key, "ease"))
	self:Cancel(controller, part(key, "impulse"))
	self:CancelHitbox(controller, key)
	self:StopTrack(controller, key, fade)
end

return AttackService
