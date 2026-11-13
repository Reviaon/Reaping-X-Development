local HttpService = game:GetService("HttpService")

local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")
local Attacks = require("../MobService/Combat/Attacks")
local Types = require("./Types")

type Profile = Types.Profile
type Spec = Types.Spec

local Profile = {}

local CLIENT_BITE = { "animation", "speed", "windup", "recovery", "cooldown", "reach", "reach_from", "radius", "step_in", "final", "step_in_lead", "step_in_ease", "step_in_rise", "range", "miss_animation", "leap" }
local CLIENT_DASH = { "speed", "playback", "recovery", "visual", "animations" }
local CLIENT_ABILITY = { "animation", "miss_animation", "speed", "windup", "recovery", "cooldown", "ability_cooldown", "reach", "range", "leap" }

local SHOT_SLOTS = 10

local cache: { [string]: Profile } = {}

local function pick(source: { [string]: any }, keys: { string }): { [string]: any }
	local picked = {}

	for _, key in keys do
		picked[key] = source[key]
	end

	return picked
end

local function holds(entry: MorphTypes.Entry): { [string]: boolean }
	local found = {}
	local shots: { MorphTypes.Shot } = entry.shots or {}

	for _, shot in shots do
		local hold = shot.hold

		if hold then
			found[hold.attribute] = true
		end
	end

	return found
end

local function abilityOrder(entry: MorphTypes.Entry, name: string, config: Types.Config): { string }
	local abilities: { [string]: any } = config.abilities or {}
	local order: { string } = {}

	if entry.abilities then
		for _, ability in entry.abilities do
			if not abilities[ability] then
				error(`[MorphService] "{name}" lists ability "{ability}", which its mob has no entry for.`, 0)
			end

			table.insert(order, ability)
		end

		return order
	end

	for ability in abilities do
		table.insert(order, ability)
	end

	table.sort(order)

	return order
end

function Profile.Label(ability: string): string
	local words = {}

	for word in string.gmatch(ability, "[^_%s]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end

	return table.concat(words, " ")
end

function Profile.Get(library: Instance, MobService: any, name: string): Profile
	local cached = cache[name]
	if cached then return cached end

	local module = library:FindFirstChild(name)

	if not module or not module:IsA("ModuleScript") then
		error(`[MorphService] "{name}" has no entry under Libraries.MorphLibrary.`, 2)
	end

	local entry = (require :: any)(module) :: MorphTypes.Entry
	local kind = MobService:GetKind(entry.mob or name) :: Types.Kind
	local config = kind.Config
	local mob = { Config = config }
	local specs: { Spec } = {}
	local combo = {}

	for index = 1, Attacks.Length(config.attack) do
		local spec = Attacks.Spec(mob, index) :: Spec
		specs[index] = spec
		combo[index] = pick(spec, CLIENT_BITE)
	end

	local order = abilityOrder(entry, name, config)
	local abilities: { [string]: Spec } = {}
	local tools = {}

	for _, ability in order do
		local spec = Attacks.Ability(mob, ability) :: Spec
		local picked = pick(spec, CLIENT_ABILITY)

		picked.name = ability
		picked.label = Profile.Label(ability)
		picked.ability_cooldown = spec.ability_cooldown or 0
		abilities[ability] = spec
		table.insert(tools, picked)
	end

	local client = {
		mob = kind.Name,
		walk_speed = config.walk_speed,
		run_speed = config.run_speed,
		animations = config.animations,
		animation_speeds = config.animation_speeds or {},
		exclusive = config.animation_exclusive or {},
		hurt = config.hurt_animations or {},
		visuals = config.visuals,
		combo_reset = config.attack.combo_reset or 0,
		combo = combo,
		abilities = tools,
		dash = if config.dash then pick(config.dash, CLIENT_DASH) else nil,
	}

	local profile: Profile = {
		Name = name,
		Entry = entry,
		Kind = kind,
		Config = config,
		Specs = specs,
		Abilities = abilities,
		AbilityOrder = order,
		Holds = holds(entry),
		Json = HttpService:JSONEncode(client),
	}

	cache[name] = profile

	return profile
end

function Profile.Describe(profile: Profile): string
	local parts = {}
	local controls: { [string]: { MorphTypes.Input } } = profile.Entry.controls or {}

	for action, inputs in controls do
		local names = {}

		for _, input in inputs do
			table.insert(names, input.Name)
		end

		table.insert(parts, `{table.concat(names, "/")} {action}`)
	end

	table.sort(parts)
	table.insert(parts, "Space jump")

	local tools = {}

	for slot, ability in profile.AbilityOrder do
		table.insert(tools, `{slot % 10} {Profile.Label(ability)}`)
	end

	local shots = {}
	local entries: { MorphTypes.Shot } = profile.Entry.shots or {}

	for index, shot in entries do
		local slot = index + #profile.AbilityOrder

		if slot <= SHOT_SLOTS then
			table.insert(shots, `{slot % 10} {shot.animation}`)
		end
	end

	local text = table.concat(parts, ", ")

	if #tools > 0 then
		text ..= `; ability tools: {table.concat(tools, ", ")}`
	end

	if #shots > 0 then
		text ..= `; clips: {table.concat(shots, ", ")}`
	end

	return text
end

return Profile
