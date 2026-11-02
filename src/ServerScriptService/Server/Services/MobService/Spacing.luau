local Spacing = {}

Spacing.Settings = {
	Margin = 1.5,
	MaxPush = 14,
	SteerGain = 2.5,
	NudgeThreshold = 1,
	CellSize = 32,
}

local Grid = {}
Grid.__index = Grid

local function cellKey(x: number, z: number): number
	return x * 1048576 + z
end

function Spacing.Grid()
	return setmetatable({ Cells = {} }, Grid)
end

function Grid:Rebuild(mobs)
	local size = Spacing.Settings.CellSize
	local cells = self.Cells

	table.clear(cells)

	for mob in mobs do
		if mob.Dead or not mob.Root then continue end

		local position = mob.Root.Position
		local key = cellKey(math.floor(position.X / size), math.floor(position.Z / size))
		local cell = cells[key]

		if not cell then
			cell = {}
			cells[key] = cell
		end

		table.insert(cell, mob)
	end
end

function Grid:Cell(position: Vector3, dx: number, dz: number)
	local size = Spacing.Settings.CellSize
	return self.Cells[cellKey(math.floor(position.X / size) + dx, math.floor(position.Z / size) + dz)]
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function closestPoints(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (Vector3, Vector3)
	local d1, d2 = q1 - p1, q2 - p2
	local r = p1 - p2
	local a, e = d1:Dot(d1), d2:Dot(d2)
	local f = d2:Dot(r)
	local s, t

	if a <= 1e-6 and e <= 1e-6 then
		return p1, p2
	end

	if a <= 1e-6 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)

		if e <= 1e-6 then
			s, t = math.clamp(-c / a, 0, 1), 0
		else
			local b = d1:Dot(d2)
			local denominator = a * e - b * b

			s = if denominator > 1e-6 then math.clamp((b * f - c * e) / denominator, 0, 1) else 0
			t = (b * s + f) / e

			if t < 0 then
				s, t = math.clamp(-c / a, 0, 1), 0
			elseif t > 1 then
				s, t = math.clamp((b - c) / a, 0, 1), 1
			end
		end
	end

	return p1 + d1 * s, p2 + d2 * t
end

local function segmentOf(mob): (Vector3, Vector3)
	local root = mob.Root
	local center = flat(root.Position)
	local look = flat(root.CFrame.LookVector)
	local axis = if look.Magnitude > 1e-3 then look.Unit * mob.Body.HalfLength else Vector3.zero

	return center - axis, center + axis
end

function Spacing.Push(mob, crowd): Vector3
	local settings = Spacing.Settings
	local body = mob.Body
	local fromA, toA = segmentOf(mob)
	local total = Vector3.zero

	local origin = mob.Root.Position

	for dx = -1, 1 do
		for dz = -1, 1 do
			local cell = crowd:Cell(origin, dx, dz)
			if not cell then continue end

			for _, other in cell do
				if other == mob or other.Dead or not other.Root or not other.Body then continue end

				local offset = flat(other.Root.Position - origin)
				local reach = body.HalfLength + body.Radius + other.Body.HalfLength + other.Body.Radius + settings.Margin

				if offset.Magnitude >= reach then continue end

				local fromB, toB = segmentOf(other)
				local pointA, pointB = closestPoints(fromA, toA, fromB, toB)
				local gap = pointA - pointB
				local distance = gap.Magnitude
				local minimum = body.Radius + other.Body.Radius + settings.Margin

				if distance >= minimum then continue end

				local away = if distance > 1e-3 then gap / distance elseif offset.Magnitude > 1e-3 then -offset.Unit else Vector3.xAxis

				total += away * (minimum - distance)
			end
		end
	end

	if total.Magnitude > settings.MaxPush then
		total = total.Unit * settings.MaxPush
	end

	return total
end

function Spacing.Steer(separation: Vector3): Vector3
	local settings = Spacing.Settings
	local steer = separation * settings.SteerGain

	if steer.Magnitude > settings.MaxPush then
		steer = steer.Unit * settings.MaxPush
	end

	return steer
end

return Spacing
