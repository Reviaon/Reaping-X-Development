--@ Combat Config
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponsLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("WeaponsLibrary")

local Defaults = require(script.Defaults)
local Scaling = require(script.Scaling)
local Schema = require(script.Schema)

local ResolveIndexed = Scaling.ResolveIndexed
local ResolveNumber = Scaling.ResolveNumber

local function BuildWeaponConfig()
	local config = {}

	for _, module in WeaponsLibrary:GetDescendants() do
		if not module:IsA("ModuleScript") then continue end

		--@ One malformed weapon module must not take the whole combat config down with it
		local loaded, data = pcall(require, module)

		if not loaded then
			warn(`[CombatConfig] Weapon module "{module:GetFullName()}" failed to load: {data}`)
			continue
		end

		Schema.Validate(module.Name, data)
		config[module.Name] = data
	end

	return config
end

local CombatConfig = {
	ComboTimeout = 1.5, --@ Default Combo Time Out
	DefaultMaxCombo = 3, --@ Default Max Combo
	DefaultWeapon = "Melee", --@ Default weapon id to resolve to when no weapon is equipped or specified.
	DefaultAttackSpeed = 1, --@ Playback multiplier for weapons that do not author attack_speed.
	InputBuffering = false, --@ When true, attack presses blocked by an active attack queue and auto-fire when ready.

	--@ Keyed by weapon id -> that weapon's module under Libraries.WeaponsLibrary.
	WeaponConfig = BuildWeaponConfig(),
}

CombatConfig.ValidateWeapon = Schema.Validate

function CombatConfig:GetMaxComboForWeapon(weaponId: string): number
	local weaponData = self.WeaponConfig[weaponId]
	if weaponData and weaponData.MaxCombo then
		return weaponData.MaxCombo
	end

	return self.DefaultMaxCombo
end

function CombatConfig:WeaponListener(controller, trove, onChanged: (weaponId: string) -> ())
	local Character = controller.Character
	if not Character then return end

	local existing = Character:FindFirstChildOfClass("Tool")
	if existing and self.WeaponConfig[existing.Name] then
		controller:Set("EquippedWeapon", existing.Name)
		if onChanged then onChanged(existing.Name) end
	end

	--@ Resolve once up front, armed or not, so the idle stance has a name to play from
	--@ the first frame instead of waiting on the next equip/unequip event.
	self:UpdateWeaponConfig(controller)

	trove:Connect(Character.ChildAdded, function(child)
		if not child:IsA("Tool") then return end
		if not self.WeaponConfig[child.Name] then
			warn("[CombatConfig] Tool '" .. child.Name .. "' has no WeaponConfig entry, ignoring.")
			return
		end

		controller:Set("EquippedWeapon", child.Name)
		self:UpdateWeaponConfig(controller)

		if onChanged then onChanged(child.Name) end
	end)

	trove:Connect(Character.ChildRemoved, function(child)
		if not child:IsA("Tool") then return end
		if controller:Get("EquippedWeapon") == child.Name then
			controller:Remove("EquippedWeapon")

			self:UpdateWeaponConfig(controller)

			if onChanged then onChanged(self.DefaultWeapon) end
		end
	end)
end

function CombatConfig:ClearImpulse(controller)
	local thread = controller:Get("_impulseThread")

	if thread then
		task.cancel(thread)
		controller:Remove("_impulseThread")
	end

	controller.PhysicsService.ClearExistingImpulse(controller)

	if controller.Character then
		local recipe = controller.KnockbackService.Active(controller.Character)

		if recipe and recipe.steer then
			controller.KnockbackService.Cancel(controller.Character)
		end
	end
end

function CombatConfig:UpdateWeaponConfig(controller)
	local Character = controller.Character
	if not Character then return end

	local equipped = self:ResolveEquippedWeapon(controller)

	controller._idle_animation = equipped and (equipped .. "Idle") or nil
end

function CombatConfig:ResolveEquippedWeapon(controller): string?
	local Character = controller.Character
	if not Character then return nil end

	local equippedTool = Character:FindFirstChildOfClass("Tool")
	if not equippedTool then return nil end

	local explicitWeapon = controller:Get("EquippedWeapon")
		or controller:Get("Weapon")
		or controller:Get("WeaponType")

	if typeof(explicitWeapon) == "string" and explicitWeapon ~= "" then
		return explicitWeapon
	end

	local attrWeapon = Character:GetAttribute("EquippedWeapon")
		or Character:GetAttribute("Weapon")
		or Character:GetAttribute("WeaponType")

	if typeof(attrWeapon) == "string" and attrWeapon ~= "" then
		return attrWeapon
	end

	return equippedTool.Name
end

function CombatConfig:ResolveWeaponId(controller): string
	local equipped = self:ResolveEquippedWeapon(controller)
	if equipped then
		return equipped
	end

	return self.DefaultWeapon
end

function CombatConfig:ResolveWeaponConfig(controller)
	local weaponId = self:ResolveWeaponId(controller)

	return self.WeaponConfig[weaponId] or {}
end

function CombatConfig:ResolveWeaponVisuals(weaponId: string): string?
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end

	if not self._visualsFolder then
		local modules = ReplicatedStorage:FindFirstChild("Modules")
		local effects = modules and modules:FindFirstChild("Effects")
		local combat = effects and effects:FindFirstChild("Combat")
		self._visualsFolder = combat and combat:FindFirstChild("Weapons")
	end

	local folder = self._visualsFolder
	local module = folder and folder:FindFirstChild(weaponId .. Defaults.Visuals.Suffix)
	if not module or not module:IsA("ModuleScript") then return nil end

	return Defaults.Visuals.Path .. module.Name
end

function CombatConfig:BuildHitboxData(hitbox)
	local data = {
		Offset = hitbox.offset,
		MaxTargets = hitbox.max_targets,
		MaxHitsPerTarget = hitbox.max_hits_per_target,
	}

	if hitbox.shape == "Sphere" then
		data.Radius = hitbox.size.X
	else
		data.Size = hitbox.size
	end

	return data
end


function CombatConfig:ResolveAttackSpeed(weaponConfig, comboIndex: number?): number
	local fallback = self.DefaultAttackSpeed or 1
	local speed = ResolveNumber(weaponConfig and weaponConfig.attack_speed, comboIndex, fallback)

	return math.clamp(speed, Defaults.MinAttackSpeed, Defaults.MaxAttackSpeed)
end

function CombatConfig:ResolveAttackTiming(controller, comboIndex: number?, weaponConfig)
	weaponConfig = weaponConfig or self:ResolveWeaponConfig(controller)
	comboIndex = comboIndex or 1

	local speed = self:ResolveAttackSpeed(weaponConfig, comboIndex)

	local maxCombo = weaponConfig.MaxCombo or self.DefaultMaxCombo
	local isFinal = comboIndex >= maxCombo

	local cooldown = isFinal
		and (weaponConfig.attack_cooldown_final or weaponConfig.attack_cooldown)
		or weaponConfig.attack_cooldown

	local impulse = weaponConfig.light_impulse
	local impulseData = impulse and (ResolveIndexed(impulse.impulse, comboIndex) or impulse) or nil

	local impulseDelay = impulse
		and ResolveNumber(impulse.impulse_delay, comboIndex, Defaults.ImpulseDelay) / speed
		or Defaults.ImpulseDelay

	local hitbox = weaponConfig.hitbox
	local hitboxData = hitbox and (ResolveIndexed(hitbox.hitbox, comboIndex) or hitbox) or nil

	local knockback = weaponConfig.knockback
	local knockbackData = knockback and (ResolveIndexed(knockback.knockback, comboIndex) or knockback) or nil

	local hitboxDelay = impulseDelay
	if hitboxData and hitboxData ~= hitbox and hitboxData.hitbox_delay ~= nil then
		hitboxDelay = ResolveNumber(hitboxData.hitbox_delay, nil, Defaults.ImpulseDelay) / speed
	elseif hitbox and hitbox.hitbox_delay ~= nil then
		hitboxDelay = ResolveNumber(hitbox.hitbox_delay, comboIndex, Defaults.ImpulseDelay) / speed
	end

	return {
		combo_index = comboIndex,
		is_final = isFinal,

		--@ Handed straight to AnimationTrack:Play and AdjustSpeed.
		speed = speed,

		duration = ResolveNumber(weaponConfig.attack_duration, comboIndex, Defaults.AttackDuration) / speed,
		cooldown = ResolveNumber(cooldown, comboIndex, Defaults.AttackCooldown) / speed,

		ease_out = ResolveNumber(weaponConfig.ease_out, comboIndex, Defaults.EaseOut) / speed,
		ease_pause = ResolveNumber(weaponConfig.ease_pause, comboIndex, Defaults.EasePause) / speed,
		ease_fade = ResolveNumber(weaponConfig.ease_fade, comboIndex, Defaults.EaseFade) / speed,

		--@ Retimed as a whole: same displacement, played at the animation's tempo, with the
		--@ cue point moving alongside it so the step still fires on the same frame.
		impulse = Scaling.Impulse(impulseData, impulse, speed),
		impulse_delay = impulseDelay,
		impulse_priority = impulseData and (impulseData.priority or impulse.priority) or 1,

		hitbox = Scaling.Hitbox(hitboxData, hitbox, speed),
		hitbox_delay = hitboxDelay,

		knockback = Scaling.Knockback(knockbackData, knockback, speed, Scaling.Impulse(impulseData, impulse, speed)),

		finisher = isFinal and Scaling.Finisher(weaponConfig.finisher) or nil,
	}
end

return CombatConfig
