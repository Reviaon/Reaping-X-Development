local Defaults = require("./Defaults")

local Config = {}

Config.Settings = {
	ReachMargin = 3,
	RangeMargin = 2,
	PounceRangeRatio = 2.2,
	ClearanceMargin = 12,
	OrbitReachRatio = 2.4,
	MinOrbitRadius = 18,
}

local function isList(value): boolean
	return typeof(value) == "table" and #value > 0
end

local function isRecord(value): boolean
	return typeof(value) == "table" and not isList(value)
end

local function merge(base, override)
	local result = {}

	for key, value in base do
		result[key] = if isRecord(value) then merge(value, {}) else value
	end

	for key, value in override do
		local current = result[key]
		result[key] = if isRecord(value) and isRecord(current) then merge(current, value) else value
	end

	return result
end

function Config.Resolve(entry)
	return merge(Defaults, entry)
end

function Config.Derive(config, body)
	local settings = Config.Settings
	local attack = config.attack

	attack.reach = attack.reach or body.HalfLength + body.Radius + settings.ReachMargin
	config.attack_range = config.attack_range or attack.reach + settings.RangeMargin

	if config.pounce then
		config.pounce.range = config.pounce.range or config.attack_range * settings.PounceRangeRatio
	end

	if config.pack then
		config.pack.clearance = config.pack.clearance or attack.reach + settings.ClearanceMargin
		config.pack.orbit_radius = config.pack.orbit_radius or math.max(attack.reach * settings.OrbitReachRatio, settings.MinOrbitRadius)
	end

	return config
end

return Config
