local CollectionService = game:GetService("CollectionService")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Rig = require("./MobService/Body/Rig")
local Zone = require("@self/Zone")
local Placement = require("@self/Placement")
local Population = require("@self/Population")
local Budget = require("@self/Budget")

local MobSpawnService = Jloader.CreateService({ Name = script.Name })

MobSpawnService.Settings = {
	ZoneTag = "MobZone", --@ CollectionService tag on the Parts that mark spawn areas (attributes: Mob, optional Cap, Respawn, Team)
	GlobalCap = 20, --@ Most mobs alive at once across the map; zones nearest a player fill first
	CheckInterval = 0.5, --@ Seconds between spawn and despawn passes
	ActivationRange = 220, --@ A zone spawns only while a player is within this many studs of its edge
	ConcealRange = 160, --@ A spawn point a player could see from within this many studs is skipped
	MinPlayerDistance = 30, --@ Studs a spawn point keeps from every player, seen or not
	MaxSlope = 40, --@ Steepest ground, in degrees, a mob may spawn on
	ClearanceMargin = 1.5, --@ Studs of free space a spawn needs around the mob's body box
	DespawnRange = 280, --@ Studs past which a mob with no player near starts to despawn
	DespawnGrace = 12, --@ Seconds a mob stays out of range before it despawns
	SpawnAttempts = 6, --@ Random anchor points tried per group before the zone waits RetryDelay
	RetryDelay = 2, --@ Seconds a zone waits after finding no usable spot
	GroundProbe = 200, --@ Studs below a zone's top the ground raycast searches
}

local MobService = nil

local Zones = {}

local function bodyOf(kind)
	local body = Rig.Body(kind.Prototype)
	body.RootHeight = kind.Prototype:GetAttribute(Rig.Settings.RootHeightAttribute) or 3

	return body
end

local function kindOf(zone)
	local name = zone.Part:GetAttribute("Mob")
	if typeof(name) ~= "string" then return nil, nil, "no Mob attribute" end

	local kind, problem = MobService:ResolveKind(name)

	return name, kind, problem
end

local function emptied(zone, now: number)
	local _, kind = kindOf(zone)
	local respawn = if kind then Zone.Spawning(zone, kind).Respawn else 0

	zone.ReadyAt = if zone.LastKillAt then zone.LastKillAt + respawn else now
	zone.LastKillAt = nil
	zone.Rolled = nil
end

local function refill(zone, room: number, now: number): number
	local settings = MobSpawnService.Settings
	local name, kind, problem = kindOf(zone)

	if not kind then
		zone.Status = problem
		return 0
	end

	if next(zone.Mobs) ~= nil then
		zone.Status = `{Zone.Alive(zone)}/{zone.Size} alive`
		return 0
	end

	if now < zone.ReadyAt then
		zone.Status = string.format("respawning in %.0fs", zone.ReadyAt - now)
		return 0
	end

	if now < zone.TryAt then return 0 end

	local spawning = Zone.Spawning(zone, kind)

	zone.Rolled = zone.Rolled or Zone.Roll(spawning)

	local count = Budget.Fit(zone.Rolled, spawning.Min, room)

	if not count then
		zone.Status = `waiting for room: needs {zone.Rolled}, {room} free`
		return 0
	end

	local group, why = Placement.Group(zone, bodyOf(kind), count, spawning.Spread, settings)

	if group and #group.Points < math.min(spawning.Min, count) then
		why = `room for only {#group.Points}`
		group = nil
	end

	if not group then
		zone.TryAt = now + settings.RetryDelay
		zone.Status = `no spot ({why})`
		return 0
	end

	local team = Zone.TeamKey(zone)

	for _, point in group.Points do
		local mob = MobService:Spawn(name, point, { Yaw = group.Yaw, Team = team, Home = group.Anchor })
		Population.Track(zone, mob)
	end

	zone.Size = #group.Points
	zone.Status = `spawned {zone.Size}`

	return zone.Size
end

local function pass(now: number)
	local settings = MobSpawnService.Settings

	for part, zone in Zones do
		local ran, problem = xpcall(function()
			if Population.Sweep(zone, MobService, settings, now) then
				emptied(zone, now)
			end
		end, debug.traceback)

		if not ran then
			warn(`[MobSpawnService] Zone {part:GetFullName()} failed to sweep:\n{problem}`)
		end
	end

	local room = settings.GlobalCap - MobService:Count()

	for _, entry in Budget.Queue(Zones, settings) do
		local zone = entry.Zone
		local ran, result = xpcall(refill, debug.traceback, zone, room, now)

		if ran then
			room -= result
		else
			warn(`[MobSpawnService] Zone {zone.Part:GetFullName()} failed to spawn:\n{result}`)
		end
	end
end

local function addZone(part: Instance)
	if not part:IsA("BasePart") or Zones[part] then return end

	Zones[part] = Zone.new(part)
end

local function removeZone(part: Instance)
	local zone = Zones[part]
	if not zone then return end

	Zones[part] = nil

	for mob in zone.Mobs do
		MobService:Despawn(mob)
	end
end

function MobSpawnService:GetZones()
	return Zones
end

function MobSpawnService:Describe(): { string }
	local lines = { `{MobService:Count()}/{self.Settings.GlobalCap} mobs alive` }

	for part, zone in Zones do
		table.insert(lines, `{part.Name} ({tostring(part:GetAttribute("Mob"))}): {zone.Status}`)
	end

	return lines
end

function MobSpawnService:Load()
	MobService = Jloader.GetService("MobService")

	local tag = self.Settings.ZoneTag

	for _, part in CollectionService:GetTagged(tag) do
		addZone(part)
	end

	CollectionService:GetInstanceAddedSignal(tag):Connect(addZone)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removeZone)

	task.spawn(function()
		while true do
			pass(os.clock())
			task.wait(self.Settings.CheckInterval)
		end
	end)
end

return MobSpawnService
