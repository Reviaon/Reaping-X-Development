local CollectionService = game:GetService("CollectionService")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Perception = require("./MobService/Perception")

local MobSpawnService = Jloader.CreateService({ Name = script.Name })

MobSpawnService.Settings = {
	ZoneTag = "MobZone", --@ CollectionService tag on the Parts that mark spawn areas
	GlobalCap = 20, --@ Most mobs alive at once across the map
	DefaultCap = 3, --@ Per-zone cap when the zone has no Cap attribute
	DefaultInterval = 8, --@ Seconds between spawns in one zone when it has no Interval attribute
	CheckInterval = 0.5, --@ Seconds between spawn and despawn passes
	ActivationRange = 220, --@ A zone spawns only while a player is within this many studs of it
	MinPlayerDistance = 30, --@ Studs a spawn point keeps from every player
	DespawnRange = 280, --@ Studs past which a mob with no player near starts to despawn
	DespawnGrace = 12, --@ Seconds a mob stays out of range before it despawns
	SpawnAttempts = 6, --@ Random points tried per spawn before the zone waits for its next turn
	GroundProbe = 200, --@ Studs below a zone's top the ground raycast searches
}

local MobService = nil

local Zones = {}
local random = Random.new()

local function settingOf(part: BasePart, attribute: string, fallback)
	local value = part:GetAttribute(attribute)
	return if typeof(value) == typeof(fallback) then value else fallback
end

local function raycastParams(): RaycastParams
	local exclude = CollectionService:GetTagged(MobSpawnService.Settings.ZoneTag)
	local live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")

	if live then
		table.insert(exclude, live)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false

	return params
end

local function findGround(part: BasePart, params: RaycastParams): Vector3?
	local settings = MobSpawnService.Settings
	local size = part.Size
	local top = part.CFrame * Vector3.new(
		random:NextNumber(-0.5, 0.5) * size.X,
		size.Y / 2,
		random:NextNumber(-0.5, 0.5) * size.Z
	)

	local result = workspace:Raycast(top, Vector3.new(0, -(size.Y + settings.GroundProbe), 0), params)
	if not result or result.Material == Enum.Material.Water then return nil end

	if Perception.NearestPlayerDistance(result.Position) < settings.MinPlayerDistance then
		return nil
	end

	return result.Position
end

local function trySpawn(zone, now: number)
	local settings = MobSpawnService.Settings
	local part = zone.Part
	local name = part:GetAttribute("Mob")

	zone.NextSpawnAt = now + settingOf(part, "Interval", settings.DefaultInterval)

	if typeof(name) ~= "string" then return end

	local params = raycastParams()

	for _ = 1, settings.SpawnAttempts do
		local ground = findGround(part, params)

		if ground then
			local mob = MobService:Spawn(name, ground, {
				Yaw = random:NextNumber(0, math.pi * 2),
				Team = part:GetAttribute("Team") or part,
			})
			zone.Mobs[mob] = { OutSince = nil }
			return
		end
	end
end

local function count(set): number
	local total = 0

	for _ in set do
		total += 1
	end

	return total
end

local function despawnPass(zone, now: number)
	local settings = MobSpawnService.Settings

	for mob, record in zone.Mobs do
		if mob.Destroyed then
			zone.Mobs[mob] = nil
			continue
		end

		if mob.Dead then continue end

		if Perception.NearestPlayerDistance(mob.Root.Position) <= settings.DespawnRange then
			record.OutSince = nil
			continue
		end

		record.OutSince = record.OutSince or now

		if now - record.OutSince >= settings.DespawnGrace then
			MobService:Despawn(mob)
		end
	end
end

local function spawnPass(zone, now: number)
	local settings = MobSpawnService.Settings
	local part = zone.Part

	if now < zone.NextSpawnAt then return end
	if count(zone.Mobs) >= settingOf(part, "Cap", settings.DefaultCap) then return end
	if MobService:Count() >= settings.GlobalCap then return end
	if Perception.NearestPlayerDistance(part.Position) > settings.ActivationRange then return end

	trySpawn(zone, now)
end

local function addZone(part: Instance)
	if not part:IsA("BasePart") or Zones[part] then return end

	Zones[part] = {
		Part = part,
		Mobs = {},
		NextSpawnAt = 0,
	}
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
			local now = os.clock()

			for part, zone in Zones do
				local ran, problem = xpcall(function()
					despawnPass(zone, now)
					spawnPass(zone, now)
				end, debug.traceback)

				if not ran then
					warn(`[MobSpawnService] Zone {part:GetFullName()} failed:\n{problem}`)
				end
			end

			task.wait(self.Settings.CheckInterval)
		end
	end)
end

return MobSpawnService
