local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Tempo = {}

local random = Random.new()

local function settingsOf(mob): MobTypes.Tempo?
	return mob.Config.tempo or nil
end

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2] or range[1])
end

local function rollCount(range: { number }): number
	return random:NextInteger(math.floor(range[1]), math.floor(range[2] or range[1]))
end

local function flurryOf(mob, tempo: MobTypes.Tempo)
	local blackboard = mob.Blackboard
	local flurry = blackboard.Flurry

	if not flurry then
		flurry = { Thrown = 0, Of = rollCount(tempo.flurry) }
		blackboard.Flurry = flurry
	end

	return flurry
end

local function weighted(moves: { [string]: number }): string?
	local total = 0

	for _, weight in moves do
		total += weight
	end

	if total <= 0 then return nil end

	local pick = random:NextNumber(0, total)

	for kind, weight in moves do
		pick -= weight
		if pick <= 0 then return kind end
	end

	return next(moves)
end

local function setupDistance(mob, tempo: MobTypes.Tempo): number?
	local setup = tempo.setup
	if not setup then return nil end

	local ability = mob.Config.abilities and mob.Config.abilities[setup.ability]
	if not ability or not ability.min_range then return nil end

	local readyAt = mob.Blackboard.AbilityReadyAt
	if readyAt and os.clock() < (readyAt[setup.ability] or 0) then return nil end

	local distance = mob:TargetDistance()
	if not distance or distance >= ability.min_range then return nil end
	if random:NextNumber() > setup.chance then return nil end

	return math.min(ability.min_range + setup.margin, ability.range)
end

local function plan(mob, tempo: MobTypes.Tempo): MobTypes.Breather?
	local side = if random:NextNumber() < 0.5 then -1 else 1
	local room = setupDistance(mob, tempo)

	if room then
		return { Kind = "setup", Side = side, Distance = room, Time = room / math.max(mob:Setting(tempo.setup and tempo.setup.speed or "walk_speed"), 1) + 1 }
	end

	local kind = weighted(tempo.moves)
	if not kind then return nil end

	if kind == "strafe" then
		return { Kind = kind, Side = side, Distance = 0, Time = roll(tempo.strafe.time) }
	end

	if kind == "back" then
		local distance = roll(tempo.back.distance)
		return { Kind = kind, Side = side, Distance = distance, Time = distance / math.max(mob:Setting(tempo.back.speed), 1) + 0.5 }
	end

	return { Kind = kind, Side = side, Distance = 0, Time = 0 }
end

function Tempo.Note(mob)
	local tempo = settingsOf(mob)
	if not tempo then return end

	local flurry = flurryOf(mob, tempo)
	flurry.Thrown += 1
end

function Tempo.Due(mob): MobTypes.Breather?
	local tempo = settingsOf(mob)
	if not tempo then return nil end

	local blackboard = mob.Blackboard
	if blackboard.Breather then return blackboard.Breather end

	local flurry = flurryOf(mob, tempo)
	if flurry.Thrown < flurry.Of then return nil end

	local breather = plan(mob, tempo)

	if not breather then
		Tempo.Finish(mob)
		return nil
	end

	blackboard.Breather = breather

	return breather
end

function Tempo.Finish(mob)
	local tempo = settingsOf(mob)
	local blackboard = mob.Blackboard
	local breather = blackboard.Breather

	blackboard.Breather = nil
	blackboard.Flurry = nil

	if tempo and tempo.setup and breather and breather.Kind == "setup" then
		blackboard.Setup = { Name = tempo.setup.ability, Until = os.clock() + tempo.setup.hold }
	end
end

function Tempo.SetUp(mob, name: string): boolean
	local setup = mob.Blackboard.Setup
	if not setup then return false end

	if os.clock() >= setup.Until then
		mob.Blackboard.Setup = nil
		return false
	end

	return setup.Name == name
end

return Tempo
