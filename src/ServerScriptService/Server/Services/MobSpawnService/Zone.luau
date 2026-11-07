local Players = game:GetService("Players")

local Zone = {}

local random = Random.new()

function Zone.new(part: BasePart)
	return {
		Part = part,
		Mobs = {},
		ReadyAt = 0,
		TryAt = 0,
		LastKillAt = nil,
		Size = nil,
		Status = "waiting for a player",
	}
end

function Zone.TeamKey(zone): any
	return zone.Part:GetAttribute("Team") or zone.Part
end

function Zone.Spawning(zone, kind)
	local spawning = kind.Config.spawn or {}
	local group = spawning.group or { 1, 1 }
	local low, high = group[1], group[2] or group[1]
	local cap = zone.Part:GetAttribute("Cap")

	if typeof(cap) == "number" then
		high = math.min(high, cap)
		low = math.min(low, high)
	end

	local respawn = zone.Part:GetAttribute("Respawn")

	return {
		Min = low,
		Max = high,
		Respawn = if typeof(respawn) == "number" then respawn else spawning.respawn or 0,
		Spread = spawning.spread or 0,
	}
end

function Zone.Roll(spawning): number
	return random:NextInteger(spawning.Min, spawning.Max)
end

function Zone.Alive(zone): number
	local alive = 0

	for mob in zone.Mobs do
		if not mob.Dead then
			alive += 1
		end
	end

	return alive
end

function Zone.Distance(zone, position: Vector3): number
	local part = zone.Part
	local half = part.Size / 2
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)

	return (localPoint - clamped).Magnitude
end

function Zone.NearestPlayer(zone): number
	local best = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			best = math.min(best, Zone.Distance(zone, root.Position))
		end
	end

	return best
end

function Zone.RandomTop(zone): Vector3
	local part = zone.Part
	local size = part.Size

	return part.CFrame * Vector3.new(random:NextNumber(-0.5, 0.5) * size.X, size.Y / 2, random:NextNumber(-0.5, 0.5) * size.Z)
end

return Zone
