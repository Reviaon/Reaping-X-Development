local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartCache = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/World/PartCache")

local Config = require("./Config")
local Types = require("./Types")

type Flight = {
	Part: BasePart,
	Velocity: Vector3,
	Axis: Vector3,
	Rate: number,
	Size: Vector3,
	Born: number,
}

local Pebbles = {}

local random = Random.new()
local cache = nil
local flying: { Flight } = {}

local function find(root: Instance, path: { string }): Instance?
	local found: Instance? = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function cacheOf()
	if cache ~= nil then return cache or nil end

	local settings = Config.Pebbles
	local source = find(ReplicatedStorage, Config.Pebble)
	local parent = find(workspace, Config.Visuals)

	if not source or not source:IsA("BasePart") or not parent then
		cache = false
		return nil
	end

	local template = source:Clone()
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.CastShadow = false

	cache = PartCache.new(template, settings.Pool, parent)
	cache.ExpansionSize = settings.PoolGrowth

	template:Destroy()

	return cache
end

local function roll(range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

function Pebbles.Kick(ground: Types.Ground, heading: Vector3)
	local pieces = cacheOf()
	if not pieces then return end

	local settings = Config.Pebbles
	local now = os.clock()

	for _ = 1, math.floor(roll(settings.Count) + 0.5) do
		local part: BasePart = pieces:GetPart()
		local side = random:NextNumber(-settings.Spread, settings.Spread)
		local back = CFrame.fromAxisAngle(Vector3.yAxis, side):VectorToWorldSpace(-heading)
		local size = Vector3.one * roll(settings.Size)

		part.Size = size
		part.Material = ground.Material
		part.MaterialVariant = ground.MaterialVariant
		part.Color = ground.Color
		part.CFrame = CFrame.new(ground.Position + ground.Normal * settings.Lift)
			* CFrame.Angles(random:NextNumber(0, 2 * math.pi), random:NextNumber(0, 2 * math.pi), 0)

		table.insert(flying, {
			Part = part,
			Velocity = back * roll(settings.Back) + Vector3.yAxis * roll(settings.Up),
			Axis = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)).Unit,
			Rate = random:NextNumber(6, 14),
			Size = size,
			Born = now,
		})
	end
end

function Pebbles.Step(dt: number)
	if #flying == 0 then return end

	local settings = Config.Pebbles
	local now = os.clock()
	local pieces = cacheOf()

	for index = #flying, 1, -1 do
		local flight = flying[index]
		local age = now - flight.Born

		if age >= settings.Lifetime then
			table.remove(flying, index)

			if pieces then
				pieces:ReturnPart(flight.Part)
			end

			continue
		end

		flight.Velocity -= Vector3.yAxis * settings.Gravity * dt

		local part = flight.Part
		part.CFrame = (part.CFrame + flight.Velocity * dt) * CFrame.fromAxisAngle(flight.Axis, flight.Rate * dt)

		local left = settings.Lifetime - age

		if left < settings.Shrink then
			part.Size = flight.Size * math.max(left / settings.Shrink, 0.01)
		end
	end
end

return Pebbles
