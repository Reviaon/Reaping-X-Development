local Players = game:GetService("Players")

local Perception = {}

function Perception.RootOf(character: Model?): BasePart?
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Perception.IsValidTarget(character: Model?): boolean
	if not character or not character.Parent then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	return humanoid ~= nil and humanoid.Health > 0 and Perception.RootOf(character) ~= nil
end

function Perception.NearestPlayer(origin: Vector3, range: number): (Model?, number)
	local best, bestDistance = nil, range

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not Perception.IsValidTarget(character) then continue end

		local distance = (Perception.RootOf(character).Position - origin).Magnitude

		if distance <= bestDistance then
			best, bestDistance = character, distance
		end
	end

	return best, bestDistance
end

function Perception.NearestPlayerDistance(origin: Vector3): number
	local best = math.huge

	for _, player in Players:GetPlayers() do
		local root = Perception.RootOf(player.Character)

		if root then
			best = math.min(best, (root.Position - origin).Magnitude)
		end
	end

	return best
end

local function segmentDistance(point: Vector3, from: Vector3, to: Vector3): number
	local axis = to - from
	local length = axis:Dot(axis)
	local along = if length > 1e-6 then math.clamp((point - from):Dot(axis) / length, 0, 1) else 0

	return (point - (from + axis * along)).Magnitude
end

function Perception.PlayersAlong(from: Vector3, to: Vector3, radius: number): { Model }
	local found = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not Perception.IsValidTarget(character) then continue end

		if segmentDistance(Perception.RootOf(character).Position, from, to) <= radius then
			table.insert(found, character)
		end
	end

	return found
end

function Perception.PlayersNear(origin: Vector3, radius: number): { Model }
	local found = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not Perception.IsValidTarget(character) then continue end

		if (Perception.RootOf(character).Position - origin).Magnitude <= radius then
			table.insert(found, character)
		end
	end

	return found
end

return Perception
