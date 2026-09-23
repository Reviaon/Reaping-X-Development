--@ Weapon table shapes and the validator that warns on unknown keys, wrong types and short arrays
local Defaults = require(script.Parent.Defaults)

local Schema = {}

Schema.Weapon = {
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
	finisher = "table|boolean",
	hitstun = "number|table",
}

Schema.Finisher = {
	enabled = "boolean",
	ragdoll = "number",
	speed = "number",
	lift = "number",
	spin = "number",
	twist = "number",
	flail = "number",
}

Schema.ImpulseEntry = {
	speed = "number",
	duration = "number",
	falloff = "number",
	priority = "number",
	influence = "number",
}

Schema.Impulse = table.clone(Schema.ImpulseEntry)
Schema.Impulse.impulse = "table"
Schema.Impulse.impulse_delay = "number|table"

Schema.KnockbackEntry = {
	speed = "number",
	duration = "number",
	falloff = "number",
	priority = "number",
	enabled = "boolean",
}

Schema.Knockback = table.clone(Schema.KnockbackEntry)
Schema.Knockback.knockback = "table"

Schema.HitboxEntry = {
	shape = "string",
	size = "Vector3",
	offset = "Vector3",
	duration = "number",
	hitbox_delay = "number",
	max_targets = "number",
	max_hits_per_target = "number",
	effect = "string",
	enabled = "boolean",
}

Schema.Hitbox = table.clone(Schema.HitboxEntry)
Schema.Hitbox.hitbox = "table"
Schema.Hitbox.hitbox_delay = "number|table"

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

local function validateEntries(weapon: string, label: string, entries, schema)
	if typeof(entries) ~= "table" then return end

	for combo, entry in entries do
		if typeof(entry) == "table" then
			validateShape(weapon, `{label}[{combo}].`, entry, schema)
		end
	end
end

function Schema.Validate(weapon: string, data)
	if typeof(data) ~= "table" then
		warn(`[CombatConfig] Weapon module "{weapon}" did not return a table.`)
		return
	end

	validateShape(weapon, "", data, Schema.Weapon)

	local maxCombo = typeof(data.MaxCombo) == "number" and data.MaxCombo or nil
	if maxCombo then
		validateLength(weapon, "attack_duration", data.attack_duration, maxCombo)
	end

	local impulse = data.light_impulse
	if typeof(impulse) == "table" then
		validateShape(weapon, "light_impulse.", impulse, Schema.Impulse)

		if maxCombo then
			validateLength(weapon, "light_impulse.impulse_delay", impulse.impulse_delay, maxCombo)
			validateLength(weapon, "light_impulse.impulse", impulse.impulse, maxCombo)
		end

		validateEntries(weapon, "light_impulse.impulse", impulse.impulse, Schema.ImpulseEntry)
	end

	local knockback = data.knockback
	if typeof(knockback) == "table" then
		validateShape(weapon, "knockback.", knockback, Schema.Knockback)
		validateEntries(weapon, "knockback.knockback", knockback.knockback, Schema.KnockbackEntry)
	end

	if typeof(data.finisher) == "table" then
		validateShape(weapon, "finisher.", data.finisher, Schema.Finisher)
	end

	local hitbox = data.hitbox
	if typeof(hitbox) == "table" then
		validateShape(weapon, "hitbox.", hitbox, Schema.Hitbox)

		if typeof(hitbox.shape) == "string" and not Defaults.HitboxShapes[hitbox.shape] then
			warn(`[CombatConfig] {weapon}.hitbox.shape "{hitbox.shape}" is not Box, Sphere or Cylinder.`)
		end

		if typeof(hitbox.hitbox) == "table" then
			for combo, entry in hitbox.hitbox do
				if typeof(entry) ~= "table" then continue end

				validateShape(weapon, `hitbox.hitbox[{combo}].`, entry, Schema.HitboxEntry)

				if typeof(entry.shape) == "string" and not Defaults.HitboxShapes[entry.shape] then
					warn(`[CombatConfig] {weapon}.hitbox.hitbox[{combo}].shape "{entry.shape}" is not Box, Sphere or Cylinder.`)
				end

				if maxCombo and typeof(combo) == "number" and combo > maxCombo then
					warn(`[CombatConfig] {weapon}.hitbox.hitbox[{combo}] is past MaxCombo {maxCombo}, so it never runs.`)
				end
			end
		end
	end
end

return Schema
