local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Obstacles = require("../MobService/World/Obstacles")
local Zone = require("./Zone")

local Placement = {}

local random = Random.new()
local probe = nil

local function excluded(settings): { Instance }
	local list = CollectionService:GetTagged(settings.ZoneTag)
	local world = workspace:FindFirstChild("World")

	for _, name in { "Live", "Visuals" } do
		local folder = world and world:FindFirstChild(name)

		if folder then
			table.insert(list, folder)
		end
	end

	return list
end

local function queries(settings)
	local list = excluded(settings)

	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = list
	ray.RespectCanCollide = true

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = list
	overlap.RespectCanCollide = true

	return { Ray = ray, Overlap = overlap }
end

local function probePart(): BasePart
	if probe and probe.Parent then return probe end

	local world = workspace:FindFirstChild("World")

	probe = Instance.new("Part")
	probe.Name = "MobSpawnProbe"
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanQuery = false
	probe.CanTouch = false
	probe.Transparency = 1
	probe.Parent = world and world:FindFirstChild("Visuals") or workspace

	return probe
end

local function ground(from: Vector3, depth: number, query, settings): (Vector3?, string?)
	local hit = workspace:Raycast(from, Vector3.new(0, -depth, 0), query.Ray)

	if not hit then return nil, "no ground" end
	if hit.Material == Enum.Material.Water then return nil, "water" end
	if hit.Normal.Y < math.cos(math.rad(settings.MaxSlope)) then return nil, "too steep" end

	return hit.Position
end

local function clear(point: Vector3, yaw: number, body, query, settings): boolean
	local part = probePart()
	local lift = 0.5
	local margin = settings.ClearanceMargin * 2
	local height = math.max(body.RootHeight * 2 - lift, 1)

	part.Size = Vector3.new(body.Radius * 2 + margin, height, (body.HalfLength + body.Radius) * 2 + margin)
	part.CFrame = CFrame.new(point + Vector3.new(0, lift + height / 2, 0)) * CFrame.Angles(0, yaw, 0)

	return #workspace:GetPartsInPart(part, query.Overlap) == 0
end

local function hidden(point: Vector3, body, query, settings): (boolean, string?)
	local target = point + Vector3.new(0, body.RootHeight, 0)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local eye = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
		if not eye then continue end

		local offset = target - eye.Position
		local distance = offset.Magnitude

		if distance < settings.MinPlayerDistance then return false, "too close to a player" end

		if distance <= settings.ConcealRange and Obstacles.Sightline(eye.Position, target, query.Ray) then
			return false, "in view of a player"
		end
	end

	return true
end

local function apart(point: Vector3, points: { Vector3 }, body): boolean
	local gap = body.Radius * 2 + body.HalfLength

	for _, other in points do
		if (Vector3.new(point.X - other.X, 0, point.Z - other.Z)).Magnitude < gap then
			return false
		end
	end

	return true
end

local function usable(point: Vector3, yaw: number, body, query, settings): (boolean, string?)
	if not clear(point, yaw, body, query, settings) then return false, "blocked" end

	return hidden(point, body, query, settings)
end

function Placement.Group(zone, body, count: number, spread: number, settings)
	local query = queries(settings)
	local depth = zone.Part.Size.Y + settings.GroundProbe
	local reason = "no attempts"

	for _ = 1, settings.SpawnAttempts do
		local yaw = random:NextNumber(0, math.pi * 2)
		local anchor, why = ground(Zone.RandomTop(zone), depth, query, settings)

		if anchor then
			local ok
			ok, why = usable(anchor, yaw, body, query, settings)

			if not ok then
				anchor = nil
			end
		end

		if not anchor then
			reason = why or reason
			continue
		end

		local points = { anchor }
		local tries = count * settings.SpawnAttempts
		local gap = body.Radius * 2 + body.HalfLength
		local reach = math.max(spread, gap * 1.5)

		while #points < count and tries > 0 do
			tries -= 1

			local angle = random:NextNumber(0, math.pi * 2)
			local distance = random:NextNumber(gap, reach)
			local from = anchor + Vector3.new(math.cos(angle) * distance, body.RootHeight * 4, math.sin(angle) * distance)
			local point = ground(from, body.RootHeight * 8, query, settings)

			if point and apart(point, points, body) and usable(point, yaw, body, query, settings) then
				table.insert(points, point)
			end
		end

		return { Anchor = anchor, Points = points, Yaw = yaw }
	end

	return nil, reason
end

return Placement
