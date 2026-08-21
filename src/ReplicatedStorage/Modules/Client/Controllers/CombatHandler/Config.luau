--@ Combat Config
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponsLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("WeaponsLibrary")

local VISUALS_SUFFIX = "Visuals"
local VISUALS_PATH = "Combat.Weapons."

local VisualsFolder = nil

local DEFAULT_ATTACK_DURATION = 0.2
local DEFAULT_ATTACK_COOLDOWN = 0.3
local DEFAULT_IMPULSE_DELAY = 0.2

local DEFAULT_IMPULSE_SPEED = 30
local DEFAULT_IMPULSE_DURATION = 0.2
local DEFAULT_IMPULSE_FALLOFF = 0.2
local DEFAULT_EASE_OUT = 0.1
local DEFAULT_EASE_PAUSE = 0.05
local DEFAULT_EASE_FADE = 0.15

local MIN_ATTACK_SPEED = 0.1
local MAX_ATTACK_SPEED = 10

local function ResolveIndexed(value: any, comboIndex: number?): any
	if typeof(value) == "table" then
		return comboIndex and value[comboIndex] or nil
	end

	return value
end

local function ResolveNumber(value: any, comboIndex: number?, fallback: number): number
	local resolved = ResolveIndexed(value, comboIndex)

	--@ resolved ~= resolved catches NaN, which would otherwise propagate silently through
	--@ every derived timing and stall the attack instead of erroring anywhere useful.
	if typeof(resolved) ~= "number" or resolved ~= resolved then
		return fallback
	end

	return resolved
end

local function ScaleImpulse(impulseData, parent, speed: number)
	if not impulseData then return nil end

	local scaled = table.clone(impulseData)

	scaled.speed = ResolveNumber(impulseData.speed, nil, DEFAULT_IMPULSE_SPEED) * speed
	scaled.duration = ResolveNumber(impulseData.duration, nil, DEFAULT_IMPULSE_DURATION) / speed
	scaled.falloff = ResolveNumber(impulseData.falloff, nil, DEFAULT_IMPULSE_FALLOFF) / speed

	if scaled.influence == nil and parent then
		scaled.influence = parent.influence
	end

	return scaled
end

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

	local trove = controller:Get("_activeImpulseTrove")
	
	if trove then
		trove:Destroy()
		controller:Remove("_activeImpulseTrove")
	end

	
	controller.PhysicsService.ClearExistingImpulse(controller)
end

function CombatConfig:UpdateWeaponConfig(controller)
	local Character = controller.Character
	if not Character then return end

	local equipped = self:ResolveEquippedWeapon(controller)

	--@ nil when unarmed: there is no stance to hold, and publishing the default weapon's
	--@ name would keep an idle playing with nothing in hand.
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

--@ Same answer with the unarmed case folded onto the default weapon, which is what the
--@ attack path wants: an unarmed swing still needs a weapon id to build animation names.
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

--@ Dotted ClientEffects path for a weapon's visual module, or nil when it has none, so a
--@ weapon without visuals is skipped instead of making every client warn about it.
function CombatConfig:ResolveWeaponVisuals(weaponId: string): string?
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end

	if not VisualsFolder then
		local modules = ReplicatedStorage:FindFirstChild("Modules")
		local effects = modules and modules:FindFirstChild("Effects")
		local combat = effects and effects:FindFirstChild("Combat")
		VisualsFolder = combat and combat:FindFirstChild("Weapons")
	end

	local module = VisualsFolder and VisualsFolder:FindFirstChild(weaponId .. VISUALS_SUFFIX)
	if not module or not module:IsA("ModuleScript") then return nil end

	return VISUALS_PATH .. module.Name
end

--========================================================================
--@ Attack timing resolution
--
--@ Every timing in a weapon module is authored at 1x - the natural length of the
--@ animation as it was exported. `attack_speed` is the single knob that decides how fast
--@ the attack actually plays, and everything that has to stay glued to the animation is
--@ derived from it here instead of being hand-tuned per weapon:
--@
--@     playback speed   = attack_speed
--@     attack_duration  \
--@     impulse_delay     |
--@     ease_out          |  authored value / attack_speed
--@     ease_pause        |
--@     ease_fade         |
--@     attack_cooldown  /
--@
--@ Doubling attack_speed therefore halves the swing, its ease-out tail, the fade and the
--@ recovery together - the rhythm is preserved and only the tempo changes. Retiming a
--@ weapon is one number, and the authored values stay a truthful record of how long the
--@ animation actually is.
--@
--@ The momentum half is retimed too, but velocity moves the OTHER way:
--@
--@     impulse duration \  authored value / attack_speed
--@     impulse falloff  /
--@     impulse speed    =  authored value * attack_speed
--@
--@ Time compresses while velocity expands by the same factor, so the step covers the
--@ same ground and simply gets there sooner, landing on the same animation frame it
--@ always did.
--@
--@ Not scaled: light_impulse.influence, which is a ratio of the player's own walk speed
--@ rather than a distance or a time, and priority, which is pure arbitration.
--========================================================================

--@ The playback multiplier for one hit. Accepts a number, or an array keyed by combo
--@ index for per-hit tuning; anything else falls back to the config-wide default.
function CombatConfig:ResolveAttackSpeed(weaponConfig, comboIndex: number?): number
	local fallback = self.DefaultAttackSpeed or 1
	local speed = ResolveNumber(weaponConfig and weaponConfig.attack_speed, comboIndex, fallback)

	return math.clamp(speed, MIN_ATTACK_SPEED, MAX_ATTACK_SPEED)
end

--@ Resolves one swing into the numbers a component actually runs on, already divided by
--@ attack_speed. A component should never reach past this into the raw weapon table for a
--@ timing - that is how the animation and everything scheduled against it drift apart.
function CombatConfig:ResolveAttackTiming(controller, comboIndex: number?, weaponConfig)
	weaponConfig = weaponConfig or self:ResolveWeaponConfig(controller)
	comboIndex = comboIndex or 1

	local speed = self:ResolveAttackSpeed(weaponConfig, comboIndex)

	--@ Falls back to the config-wide default so a weapon that never declared MaxCombo still
	--@ resolves a number here - comparing comboIndex against a nil MaxCombo used to throw.
	local maxCombo = weaponConfig.MaxCombo or self.DefaultMaxCombo
	local isFinal = comboIndex >= maxCombo

	local cooldown = isFinal
		and (weaponConfig.attack_cooldown_final or weaponConfig.attack_cooldown)
		or weaponConfig.attack_cooldown

	local impulse = weaponConfig.light_impulse
	local impulseData = impulse and (ResolveIndexed(impulse.impulse, comboIndex) or impulse) or nil

	return {
		combo_index = comboIndex,
		is_final = isFinal,

		--@ Handed straight to AnimationTrack:Play and AdjustSpeed.
		speed = speed,

		duration = ResolveNumber(weaponConfig.attack_duration, comboIndex, DEFAULT_ATTACK_DURATION) / speed,
		cooldown = ResolveNumber(cooldown, comboIndex, DEFAULT_ATTACK_COOLDOWN) / speed,

		ease_out = ResolveNumber(weaponConfig.ease_out, comboIndex, DEFAULT_EASE_OUT) / speed,
		ease_pause = ResolveNumber(weaponConfig.ease_pause, comboIndex, DEFAULT_EASE_PAUSE) / speed,
		ease_fade = ResolveNumber(weaponConfig.ease_fade, comboIndex, DEFAULT_EASE_FADE) / speed,

		--@ Retimed as a whole: same displacement, played at the animation's tempo, with the
		--@ cue point moving alongside it so the step still fires on the same frame.
		impulse = ScaleImpulse(impulseData, impulse, speed),
		impulse_delay = impulse
			and ResolveNumber(impulse.impulse_delay, comboIndex, DEFAULT_IMPULSE_DELAY) / speed
			or DEFAULT_IMPULSE_DELAY,
		impulse_priority = impulseData and (impulseData.priority or impulse.priority) or 1,
	}
end

return CombatConfig
