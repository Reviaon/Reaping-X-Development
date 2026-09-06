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
--@ Seconds a lunge or shove takes to reach full speed. 0 is an instant step.
local DEFAULT_RAMP_IN = 0.06
--@ Whether a hit turns the victim to face their attacker, and how sharply.
local DEFAULT_KNOCKBACK_FACE = true
local DEFAULT_KNOCKBACK_FACE_RESPONSIVENESS = 100
local DEFAULT_IMPULSE_DURATION = 0.2
local DEFAULT_IMPULSE_FALLOFF = 0.2
local DEFAULT_HITBOX_DURATION = 0.1
local HITBOX_SHAPES = { Box = true, Sphere = true, Cylinder = true }
local DEFAULT_HITBOX_SIZE = Vector3.new(6, 5, 7)
local DEFAULT_HITBOX_OFFSET = Vector3.new(0, 0, -4)
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
	scaled.rampIn = ResolveNumber(impulseData.rampIn, nil, DEFAULT_RAMP_IN) / speed

	if scaled.influence == nil and parent then
		scaled.influence = parent.influence
	end

	if scaled.distance == nil and parent then
		scaled.distance = parent.distance
	end

	--@ Studs. Absent, the lunge covers whatever the speed/duration/falloff curve integrates to.
	if scaled.distance ~= nil then
		scaled.distance = ResolveNumber(scaled.distance, nil, 0)
	end

	return scaled
end

local function ScaleKnockback(knockbackData, parent, speed: number, impulse)
	local scaled = knockbackData and table.clone(knockbackData) or {}

	if parent then
		if scaled.speed == nil then scaled.speed = parent.speed end
		if scaled.duration == nil then scaled.duration = parent.duration end
		if scaled.falloff == nil then scaled.falloff = parent.falloff end
		if scaled.priority == nil then scaled.priority = parent.priority end
		if scaled.enabled == nil then scaled.enabled = parent.enabled end
		if scaled.face == nil then scaled.face = parent.face end
		if scaled.faceResponsiveness == nil then scaled.faceResponsiveness = parent.faceResponsiveness end
		if scaled.distance == nil then scaled.distance = parent.distance end
	end

	if scaled.speed ~= nil then
		scaled.speed = ResolveNumber(scaled.speed, nil, DEFAULT_IMPULSE_SPEED) * speed
	end
	if scaled.duration ~= nil then
		scaled.duration = ResolveNumber(scaled.duration, nil, DEFAULT_IMPULSE_DURATION) / speed
	end
	if scaled.falloff ~= nil then
		scaled.falloff = ResolveNumber(scaled.falloff, nil, DEFAULT_IMPULSE_FALLOFF) / speed
	end

	--@ A knockback that names nothing of its own takes the attacker's lunge curve wholesale, so the
	--@ shove and the step that delivered it cover the same studs by construction.
	if impulse then
		if scaled.speed == nil then scaled.speed = impulse.speed end
		if scaled.duration == nil then scaled.duration = impulse.duration end
		if scaled.falloff == nil then scaled.falloff = impulse.falloff end
		if scaled.rampIn == nil then scaled.rampIn = impulse.rampIn end
		if scaled.distance == nil then scaled.distance = impulse.distance end
	end

	scaled.speed = scaled.speed or DEFAULT_IMPULSE_SPEED
	scaled.duration = scaled.duration or DEFAULT_IMPULSE_DURATION
	scaled.falloff = scaled.falloff or DEFAULT_IMPULSE_FALLOFF
	scaled.priority = scaled.priority or 1
	scaled.rampIn = ResolveNumber(scaled.rampIn, nil, DEFAULT_RAMP_IN)

	if scaled.face == nil then
		scaled.face = DEFAULT_KNOCKBACK_FACE
	end

	scaled.faceResponsiveness = ResolveNumber(
		scaled.faceResponsiveness, nil, DEFAULT_KNOCKBACK_FACE_RESPONSIVENESS)

	--@ Studs. Absent, the shove covers whatever the speed/duration/falloff curve integrates to.
	if scaled.distance ~= nil then
		scaled.distance = ResolveNumber(scaled.distance, nil, 0)
	end

	return scaled
end

local function ScaleHitbox(hitboxData, parent, speed: number)
	local scaled = hitboxData and table.clone(hitboxData) or {}

	if parent then
		if scaled.shape == nil then scaled.shape = parent.shape end
		if scaled.size == nil then scaled.size = parent.size end
		if scaled.offset == nil then scaled.offset = parent.offset end
		if scaled.duration == nil then scaled.duration = parent.duration end
		if scaled.max_targets == nil then scaled.max_targets = parent.max_targets end
		if scaled.max_hits_per_target == nil then scaled.max_hits_per_target = parent.max_hits_per_target end
		if scaled.enabled == nil then scaled.enabled = parent.enabled end
		if scaled.effect == nil then scaled.effect = parent.effect end
	end

	local shape = scaled.shape or "Box"
	if not HITBOX_SHAPES[shape] then
		warn(`[CombatConfig] Hitbox shape "{tostring(shape)}" is not one of Box/Sphere/Cylinder - using Box.`)
		shape = "Box"
	end

	scaled.shape = shape
	scaled.size = typeof(scaled.size) == "Vector3" and scaled.size or DEFAULT_HITBOX_SIZE
	scaled.offset = typeof(scaled.offset) == "Vector3" and scaled.offset or DEFAULT_HITBOX_OFFSET
	scaled.max_targets = ResolveNumber(scaled.max_targets, nil, -1)
	scaled.max_hits_per_target = ResolveNumber(scaled.max_hits_per_target, nil, 1)
	scaled.duration = ResolveNumber(scaled.duration, nil, DEFAULT_HITBOX_DURATION) / speed

	return scaled
end

local WEAPON_SCHEMA = {
	Rig = "string",
	RigAttachments = "table",
	MaxCombo = "number",
	attack_speed = "number|table",
	attack_cooldown = "number|table",
	attack_cooldown_final = "number|table",
	attack_duration = "number|table",
	ease_out = "number|table",
	ease_pause = "number|table",
	ease_fade = "number|table",
	light_impulse = "table",
	hitbox = "table",
	knockback = "table",
}

local IMPULSE_ENTRY_SCHEMA = {
	speed = "number",
	duration = "number",
	falloff = "number",
	priority = "number",
	influence = "number",
}

local IMPULSE_SCHEMA = table.clone(IMPULSE_ENTRY_SCHEMA)
IMPULSE_SCHEMA.impulse = "table"
IMPULSE_SCHEMA.impulse_delay = "number|table"

local KNOCKBACK_ENTRY_SCHEMA = {
	speed = "number",
	duration = "number",
	falloff = "number",
	priority = "number",
	enabled = "boolean",
}

local KNOCKBACK_SCHEMA = table.clone(KNOCKBACK_ENTRY_SCHEMA)
KNOCKBACK_SCHEMA.knockback = "table"

local HITBOX_ENTRY_SCHEMA = {
	shape = "string",
	size = "Vector3",
	offset = "Vector3",
	duration = "number",
	max_targets = "number",
	max_hits_per_target = "number",
	effect = "string",
	enabled = "boolean",
}

local HITBOX_SCHEMA = table.clone(HITBOX_ENTRY_SCHEMA)
HITBOX_SCHEMA.hitbox = "table"
HITBOX_SCHEMA.hitbox_delay = "number|table"

local function typeMatches(value, spec: string): boolean
	for expected in string.gmatch(spec, "[^|]+") do
		if typeof(value) == expected then
			return true
		end
	end

	return false
end

local function distance(a: string, b: string): number
	local rows = {}

	for i = 0, #a do
		rows[i] = { [0] = i }
	end

	for j = 0, #b do
		rows[0][j] = j
	end

	for i = 1, #a do
		for j = 1, #b do
			local cost = string.sub(a, i, i) == string.sub(b, j, j) and 0 or 1
			local value = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)

			if
				i > 1 and j > 1
				and string.sub(a, i, i) == string.sub(b, j - 1, j - 1)
				and string.sub(a, i - 1, i - 1) == string.sub(b, j, j)
			then
				value = math.min(value, rows[i - 2][j - 2] + 1)
			end

			rows[i][j] = value
		end
	end

	return rows[#a][#b]
end

local function nearestKey(key: string, schema): string?
	local best, bestScore = nil, math.huge
	local lowered = string.lower(key)

	for known in schema do
		local score = distance(lowered, string.lower(known))

		if score < bestScore then
			best, bestScore = known, score
		end
	end

	if best and bestScore <= math.max(2, math.floor(#key / 3)) then
		return best
	end

	return nil
end

local function validateShape(weapon: string, label: string, tbl, schema)
	for key, value in tbl do
		if typeof(key) ~= "string" then continue end

		local spec = schema[key]

		if spec == nil then
			local suggestion = nearestKey(key, schema)
			warn(`[CombatConfig] {weapon}.{label}{key} is not a known key{suggestion and `, did you mean "{suggestion}"?` or "."}`)
		elseif not typeMatches(value, spec) then
			warn(`[CombatConfig] {weapon}.{label}{key} should be {spec}, got {typeof(value)}.`)
		end
	end
end

local function validateLength(weapon: string, label: string, value, maxCombo: number)
	if typeof(value) ~= "table" or typeof(maxCombo) ~= "number" then return end
	if next(value) == nil or #value == 0 then return end

	if #value < maxCombo then
		warn(`[CombatConfig] {weapon}.{label} has {#value} entries but MaxCombo is {maxCombo}; the rest fall back to defaults.`)
	end
end

local function ValidateWeapon(weapon: string, data)
	if typeof(data) ~= "table" then
		warn(`[CombatConfig] Weapon module "{weapon}" did not return a table.`)
		return
	end

	validateShape(weapon, "", data, WEAPON_SCHEMA)

	local maxCombo = typeof(data.MaxCombo) == "number" and data.MaxCombo or nil
	if maxCombo then
		validateLength(weapon, "attack_duration", data.attack_duration, maxCombo)
	end

	local impulse = data.light_impulse
	if typeof(impulse) == "table" then
		validateShape(weapon, "light_impulse.", impulse, IMPULSE_SCHEMA)

		if maxCombo then
			validateLength(weapon, "light_impulse.impulse_delay", impulse.impulse_delay, maxCombo)
			validateLength(weapon, "light_impulse.impulse", impulse.impulse, maxCombo)
		end

		if typeof(impulse.impulse) == "table" then
			for combo, entry in impulse.impulse do
				if typeof(entry) == "table" then
					validateShape(weapon, `light_impulse.impulse[{combo}].`, entry, IMPULSE_ENTRY_SCHEMA)
				end
			end
		end
	end

	local knockback = data.knockback
	if typeof(knockback) == "table" then
		validateShape(weapon, "knockback.", knockback, KNOCKBACK_SCHEMA)

		if typeof(knockback.knockback) == "table" then
			for combo, entry in knockback.knockback do
				if typeof(entry) == "table" then
					validateShape(weapon, `knockback.knockback[{combo}].`, entry, KNOCKBACK_ENTRY_SCHEMA)
				end
			end
		end
	end

	local hitbox = data.hitbox
	if typeof(hitbox) == "table" then
		validateShape(weapon, "hitbox.", hitbox, HITBOX_SCHEMA)

		if typeof(hitbox.shape) == "string" and not HITBOX_SHAPES[hitbox.shape] then
			warn(`[CombatConfig] {weapon}.hitbox.shape "{hitbox.shape}" is not Box, Sphere or Cylinder.`)
		end

		if typeof(hitbox.hitbox) == "table" then
			for combo, entry in hitbox.hitbox do
				if typeof(entry) ~= "table" then continue end

				validateShape(weapon, `hitbox.hitbox[{combo}].`, entry, HITBOX_ENTRY_SCHEMA)

				if typeof(entry.shape) == "string" and not HITBOX_SHAPES[entry.shape] then
					warn(`[CombatConfig] {weapon}.hitbox.hitbox[{combo}].shape "{entry.shape}" is not Box, Sphere or Cylinder.`)
				end

				if maxCombo and typeof(combo) == "number" and combo > maxCombo then
					warn(`[CombatConfig] {weapon}.hitbox.hitbox[{combo}] is past MaxCombo {maxCombo}, so it never runs.`)
				end
			end
		end
	end
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

		ValidateWeapon(module.Name, data)
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

CombatConfig.ValidateWeapon = ValidateWeapon

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
		controller.KnockbackService.Cancel(controller.Character)
	end
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

--========================================================================
--@ Attack timing resolution
--@ Weapon timings are authored at 1x; `attack_speed` retimes them here, so retuning a weapon
--@ is one number. Divided by attack_speed: attack_duration, impulse_delay, ease_out/pause/fade,
--@ attack_cooldown, impulse duration + falloff. Multiplied by it: impulse speed, so the step
--@ covers the same ground and just gets there sooner. Not scaled: light_impulse.influence
--@ (a ratio of walk speed) and priority (pure arbitration).
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

	local impulseDelay = impulse
		and ResolveNumber(impulse.impulse_delay, comboIndex, DEFAULT_IMPULSE_DELAY) / speed
		or DEFAULT_IMPULSE_DELAY

	local hitbox = weaponConfig.hitbox
	local hitboxData = hitbox and (ResolveIndexed(hitbox.hitbox, comboIndex) or hitbox) or nil

	local knockback = weaponConfig.knockback
	local knockbackData = knockback and (ResolveIndexed(knockback.knockback, comboIndex) or knockback) or nil

	local hitboxDelay = impulseDelay
	if hitbox and hitbox.hitbox_delay ~= nil then
		hitboxDelay = ResolveNumber(hitbox.hitbox_delay, comboIndex, DEFAULT_IMPULSE_DELAY) / speed
	end

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
		impulse_delay = impulseDelay,
		impulse_priority = impulseData and (impulseData.priority or impulse.priority) or 1,

		hitbox = ScaleHitbox(hitboxData, hitbox, speed),
		hitbox_delay = hitboxDelay,

		knockback = ScaleKnockback(knockbackData, knockback, speed, ScaleImpulse(impulseData, impulse, speed)),
	}
end

return CombatConfig
