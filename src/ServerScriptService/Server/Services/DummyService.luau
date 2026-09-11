local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local DummyService = Jloader.CreateService({ Name = script.Name })

local CombatConfig = require(
	ReplicatedStorage:WaitForChild("Modules")
		:WaitForChild("Client")
		:WaitForChild("Controllers")
		:WaitForChild("Character")
		:WaitForChild("CombatHandler")
		:WaitForChild("Config")
)

local NPCLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("NPCLibrary")
local Animations = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Animations")

DummyService.Settings = {
	--@ Model attribute that switches the brain on; absent, the NPCLibrary `aggressive` key decides.
	AggressiveAttribute = "Aggressive",

	--@ Model attributes that override the NPCLibrary combat keys while the game runs.
	Overrides = {
		AggroRange = "aggro_range",
		AttackRange = "attack_range",
		AttackInterval = "attack_interval",
		Weapon = "weapon",
	},

	--@ Used for any combat key the NPC's library entry leaves out. attack_range is derived from the
	--@ next hit's hitbox reach unless the entry or attribute sets one.
	Defaults = {
		aggressive = false,
		weapon = "Melee",
		aggro_range = 30,
		attack_interval = 0.6,
		chase = true,
	},

	--@ Studs inside the hitbox's far edge the target must be before the dummy swings.
	ReachMargin = 0.5,

	--@ Seconds between MoveTo refreshes while chasing.
	MoveRefresh = 0.2,

	--@ How sharply the AlignOrientation turns the dummy onto its target while it stands and swings.
	FacingResponsiveness = 25,
	FacingName = "@dummy_facing",

	IdleSuffix = "Idle",
	IdlePriority = Enum.AnimationPriority.Action,
	IdleFade = 0.3,

	--@ NPCLibrary entry for an NPC with none of its own.
	FallbackConfig = "Template",

	HitEffectPath = "Combat.Hit",
	HitEffectMethod = "Emit",
}

local SWING = "DummySwing"

local Brains = {}
local Connection = nil
local CombatService = nil
local EffectService = nil
local WarnedWeapons = {}
local WarnedAnimations = {}

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function libraryConfig(character)
	local entry = NPCLibrary:FindFirstChild(character.Name)
		or NPCLibrary:FindFirstChild(DummyService.Settings.FallbackConfig)

	if not entry or not entry:IsA("ModuleScript") then return nil end

	local loaded, config = pcall(require, entry)
	if not loaded or typeof(config) ~= "table" then return nil end

	return config.combat
end

local function resolveConfig(brain)
	local settings = DummyService.Settings
	local config = table.clone(settings.Defaults)

	for key, value in brain.Library or {} do
		config[key] = value
	end

	for attribute, key in settings.Overrides do
		local value = brain.Character:GetAttribute(attribute)

		if value ~= nil and (config[key] == nil and typeof(value) == "number" or typeof(value) == typeof(config[key])) then
			config[key] = value
		end
	end

	return config
end

local ReachCache = {}

local function reachOf(weaponId, combo)
	local cached = ReachCache[weaponId] and ReachCache[weaponId][combo]
	if cached then return cached end

	local timing = CombatConfig:ResolveAttackTiming(nil, combo, CombatConfig.WeaponConfig[weaponId])
	local hitbox = timing.hitbox
	local depth = hitbox.shape == "Box" and hitbox.size.Z / 2 or hitbox.size.X
	local reach = math.abs(hitbox.offset.Z) + depth

	ReachCache[weaponId] = ReachCache[weaponId] or {}
	ReachCache[weaponId][combo] = reach

	return reach
end

local function nextCombo(brain, weaponId, now)
	if now - brain.LastSwingAt >= CombatConfig.ComboTimeout then
		return 1
	end

	return brain.Combo % CombatConfig:GetMaxComboForWeapon(weaponId) + 1
end

local function attackRange(brain, config, weaponId, now)
	if typeof(config.attack_range) == "number" then
		return config.attack_range
	end

	return math.max(reachOf(weaponId, nextCombo(brain, weaponId, now)) - DummyService.Settings.ReachMargin, 1)
end

local function isAggressive(brain)
	local value = brain.Character:GetAttribute(DummyService.Settings.AggressiveAttribute)

	if typeof(value) == "boolean" then
		return value
	end

	return resolveConfig(brain).aggressive == true
end

local function isAlive(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function warnOnce(registry, key, message)
	if registry[key] then return end

	registry[key] = true
	warn(message)
end

local function nearestPlayer(brain, range)
	local origin = brain.Root.Position
	local best, bestDistance = nil, range

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = rootOf(character)

		if not root or not character.Parent or not isAlive(character) then continue end

		local distance = flat(root.Position - origin).Magnitude

		if distance <= bestDistance then
			best, bestDistance = character, distance
		end
	end

	return best, bestDistance
end

local function applyProperties(brain)
	local defaults = GlobalFunctions.ServerController.CharacterProfile.DefaultSettings
	local properties = GlobalFunctions.StatusService:ResolveProperties(brain.Character, {
		WalkSpeed = defaults.WalkSpeed,
		JumpPower = defaults.JumpPower,
	})

	brain.Humanoid.WalkSpeed = math.max(0, properties.WalkSpeed)
	brain.Humanoid.JumpPower = math.max(0, properties.JumpPower)
end

local function weaponIdOf(brain, config)
	local weaponId = config.weapon

	if CombatConfig.WeaponConfig[weaponId] then
		return weaponId
	end

	warnOnce(WarnedWeapons, weaponId, `[DummyService] "{tostring(weaponId)}" has no entry under Libraries.WeaponsLibrary, so {brain.Character.Name} falls back to {CombatConfig.DefaultWeapon}.`)

	return CombatConfig.DefaultWeapon
end

local function ensureWeapon(brain, weaponId)
	if brain.WeaponId == weaponId then return end

	local character = brain.Character
	brain.WeaponId = weaponId

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name ~= weaponId then
			child:Destroy()
		end
	end

	if weaponId == CombatConfig.DefaultWeapon then return end
	if character:FindFirstChild(weaponId) then return end

	local tool, problem = GlobalFunctions.ServerController.CharacterProfile.BuildWeaponTool(weaponId)

	if not tool then
		warnOnce(WarnedWeapons, "tool", `[DummyService] {problem}`)
		return
	end

	tool.Parent = character
end

local function stopIdle(brain)
	local track = brain.IdleTrack
	if not track then return end

	brain.IdleTrack = nil
	brain.IdleName = nil
	track:Stop(DummyService.Settings.IdleFade)
end

local function updateIdle(brain, weaponId, wanted)
	local settings = DummyService.Settings
	local name = weaponId .. settings.IdleSuffix

	if not wanted or weaponId == CombatConfig.DefaultWeapon or not Animations:FindFirstChild(name, true) then
		stopIdle(brain)
		return
	end

	if brain.IdleName ~= name then
		stopIdle(brain)
	end

	if brain.IdleTrack and brain.IdleTrack.IsPlaying then return end

	brain.IdleName = name
	brain.IdleTrack = GlobalFunctions.AnimatorService:PlayTrack(brain.Character, name, {
		Speed = 1,
		Priority = settings.IdlePriority,
		FadeTime = settings.IdleFade,
		Loop = true,
	})
end

local function facingOf(brain)
	local settings = DummyService.Settings
	local root = brain.Root
	local existing = root:FindFirstChild(settings.FacingName)

	if existing and existing:IsA("AlignOrientation") then
		return existing
	end

	local attachment = GlobalFunctions.PhysicsService.ImpulseAttachment(root)
	if not attachment then return nil end

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = settings.FacingName
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = math.huge
	orientation.Responsiveness = settings.FacingResponsiveness
	orientation.Enabled = false
	orientation.Parent = root

	return orientation
end

local function face(brain, target)
	local root = brain.Root
	local direction = flat(rootOf(target).Position - root.Position)

	if direction.Magnitude <= 0 then return end

	local orientation = facingOf(brain)
	if not orientation then return end

	orientation.CFrame = CFrame.lookAt(root.Position, root.Position + direction.Unit)
	orientation.Enabled = true
end

local function unface(brain)
	local orientation = brain.Root:FindFirstChild(DummyService.Settings.FacingName)

	if orientation and orientation.Enabled then
		orientation.Enabled = false
	end
end

local function stopMoving(brain)
	if not brain.Chasing then return end

	brain.Chasing = false
	brain.Humanoid.AutoRotate = false
	brain.Humanoid:MoveTo(brain.Root.Position)
end

local function chase(brain, target, now)
	unface(brain)

	if brain.Chasing and now - brain.MovedAt < DummyService.Settings.MoveRefresh then return end

	brain.Chasing = true
	brain.MovedAt = now
	brain.Humanoid.AutoRotate = true
	brain.Humanoid:MoveTo(rootOf(target).Position)
end

local function disposeHitbox(brain)
	local handle = brain.Hitbox

	if handle then
		brain.Hitbox = nil

		if not handle.Disposed then
			handle:Dispose()
		end
	end
end

local function onHit(brain, target, weaponId, timing)
	local character = brain.Character

	if target == character then return end
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	if not target:FindFirstChildOfClass("Humanoid") then return end

	local settings = DummyService.Settings

	EffectService.CreateVisual:FireAll({
		Effect = settings.HitEffectPath,
		Method = settings.HitEffectMethod,
		Info = {
			Target = target,
			Attacker = character,
			Effect = timing.hitbox.effect,
			WeaponId = weaponId,
			ComboIndex = timing.combo_index,
		},
	})

	CombatService:ApplyKnockback(character, target, nil, weaponId, timing.combo_index)
end

local function scheduleHitbox(brain, weaponId, timing)
	local AttackService = GlobalFunctions.AttackService
	local character = brain.Character
	local hitbox = timing.hitbox

	if not hitbox or hitbox.enabled == false then return end

	AttackService:Schedule(brain, SWING .. "/hitbox", timing.hitbox_delay, function()
		if not character.Parent or not isAlive(character) then return end

		local living = livingFolder()
		if not living then return end

		local data = CombatConfig:BuildHitboxData(hitbox)
		data.Attacker = character
		data.Debug = GlobalFunctions.DebugService.IsEnabled()

		disposeHitbox(brain)

		local handle = GlobalFunctions.HitboxService.New(hitbox.shape, data, { living }, { character })
		brain.Hitbox = handle

		handle.onHit:Connect(function(target)
			onHit(brain, target, weaponId, timing)
		end)

		task.delay(hitbox.duration, function()
			if brain.Hitbox == handle then
				disposeHitbox(brain)
			end
		end)
	end)
end

local function swing(brain, config, weaponId, now)
	local AttackService = GlobalFunctions.AttackService
	local character = brain.Character
	local weaponConfig = CombatConfig.WeaponConfig[weaponId]

	brain.Combo = nextCombo(brain, weaponId, now)

	local timing = CombatConfig:ResolveAttackTiming(nil, brain.Combo, weaponConfig)
	local animationName = weaponId .. "Attack" .. brain.Combo

	if not Animations:FindFirstChild(animationName, true) then
		warnOnce(WarnedAnimations, animationName, `[DummyService] Storage.Animations has no "{animationName}", so {character.Name} cannot swing {weaponId} combo {brain.Combo}.`)
		brain.NextSwingAt = now + timing.cooldown
		return
	end

	brain.LastSwingAt = now
	brain.Swinging = true
	brain.NextSwingAt = now + math.max(timing.duration, timing.cooldown)

	if timing.is_final then
		brain.NextSwingAt += config.attack_interval
	end

	stopIdle(brain)

	local track = AttackService:SwapTrack(brain, SWING, character, animationName, {
		Speed = timing.speed,
		Priority = Enum.AnimationPriority.Action4,
		FadeTime = 0.1,
		Loop = false,
	})

	AttackService:ScheduleEaseOut(brain, SWING, track, timing)

	local visuals = CombatConfig:ResolveWeaponVisuals(weaponId)

	if visuals then
		EffectService.CreateVisual:FireAll({
			Effect = visuals,
			Method = "Attack",
			Info = {
				Character = character,
				ComboIndex = brain.Combo,
				Speed = timing.speed,
				WeaponId = weaponId,
			},
		})
	end

	scheduleHitbox(brain, weaponId, timing)
	AttackService:ScheduleImpulse(brain, SWING, character, timing)

	GlobalFunctions.StatusService:SetStatus(character, "IsAttacking", true, timing.duration)

	AttackService:Schedule(brain, SWING .. "/end", timing.duration, function()
		brain.Swinging = false
	end)
end

local function interrupt(brain)
	GlobalFunctions.AttackService:CancelSwing(brain, SWING)
	disposeHitbox(brain)
	brain.Swinging = false
end

local function step(brain, now)
	local character = brain.Character
	local StatusService = GlobalFunctions.StatusService
	local config = resolveConfig(brain)
	local weaponId = weaponIdOf(brain, config)

	ensureWeapon(brain, weaponId)

	if not isAggressive(brain) then
		stopMoving(brain)
		unface(brain)
		updateIdle(brain, weaponId, false)
		return
	end

	local recipe = GlobalFunctions.KnockbackService.Active(character)

	if StatusService:CheckStatuses(character, { IsStunned = true }) or (recipe and not recipe.steer) then
		stopMoving(brain)
		unface(brain)
		interrupt(brain)
		updateIdle(brain, weaponId, false)
		return
	end

	local target, distance = nearestPlayer(brain, config.aggro_range)

	if not target then
		stopMoving(brain)
		unface(brain)
		updateIdle(brain, weaponId, true)
		return
	end

	if distance > attackRange(brain, config, weaponId, now) then
		if config.chase and not brain.Swinging then
			chase(brain, target, now)
			updateIdle(brain, weaponId, false)
		else
			stopMoving(brain)
			face(brain, target)
			updateIdle(brain, weaponId, not brain.Swinging)
		end

		return
	end

	stopMoving(brain)
	face(brain, target)

	if not brain.Swinging and now >= brain.NextSwingAt then
		swing(brain, config, weaponId, now)
	end

	updateIdle(brain, weaponId, not brain.Swinging)
end

local function removeBrain(character)
	local brain = Brains[character]
	if not brain then return end

	Brains[character] = nil
	interrupt(brain)
	stopIdle(brain)

	local orientation = brain.Root:FindFirstChild(DummyService.Settings.FacingName)
	if orientation then
		orientation:Destroy()
	end

	brain.Trove:Destroy()
end

local function createBrain(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)

	if not humanoid or not root then return nil end

	local brain = setmetatable({
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Library = libraryConfig(character),
		Trove = GlobalFunctions.Trove.new(),
		Combo = 0,
		LastSwingAt = 0,
		NextSwingAt = 0,
		Swinging = false,
		Chasing = false,
		MovedAt = 0,
		Hitbox = nil,
		WeaponId = nil,
		IdleTrack = nil,
		IdleName = nil,
	}, { __index = GlobalFunctions })

	Brains[character] = brain

	brain.Trove:Connect(humanoid.Died, function()
		removeBrain(character)
	end)

	brain.Trove:Connect(character.AncestryChanged, function()
		if not character:IsDescendantOf(game) then
			removeBrain(character)
		end
	end)

	brain.Trove:Connect(character.AttributeChanged, function()
		applyProperties(brain)
	end)

	applyProperties(brain)

	return brain
end

local function heartbeat()
	local living = livingFolder()
	if not living then return end

	local now = os.clock()

	for _, character in living:GetChildren() do
		if not character:IsA("Model") then continue end
		if Players:GetPlayerFromCharacter(character) then continue end
		if not GlobalFunctions.ServerController:GetProfile(character) then continue end

		local brain = Brains[character] or createBrain(character)
		if not brain then continue end

		step(brain, now)
	end
end

function DummyService:SetAggressive(character, enabled)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return false end
	if Players:GetPlayerFromCharacter(character) then return false end

	character:SetAttribute(self.Settings.AggressiveAttribute, enabled and true or false)
	return true
end

function DummyService:IsAggressive(character)
	local brain = Brains[character]
	if brain then return isAggressive(brain) end

	return character:GetAttribute(self.Settings.AggressiveAttribute) == true
end

function DummyService:Load()
	CombatService = Jloader.GetService("CombatService")
	EffectService = Jloader.GetService("EffectService")

	if Connection then
		Connection:Disconnect()
	end

	Connection = RunService.Heartbeat:Connect(heartbeat)
end

return DummyService
