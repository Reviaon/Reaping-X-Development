local Config = require("./Config")

local AimLine = {}

local function planar(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function AimLine.FromRay(origin: Vector3, direction: Vector3)
	local look = planar(direction)
	if look.Magnitude < 1e-3 then return nil end

	look = look.Unit

	return {
		Origin = origin,
		Look = look,
		Side = Vector3.new(-look.Z, 0, look.X),
	}
end

function AimLine.Of(archer: BasePart)
	return AimLine.FromRay(archer.Position, archer.CFrame.LookVector)
end

function AimLine.Touches(line, mob, settings): boolean
	local along = AimLine.Along(line, mob.Root.Position)
	return along > 0 and along <= settings.range and AimLine.Gap(line, mob) <= settings.margin
end

function AimLine.Along(line, position: Vector3): number
	return planar(position - line.Origin):Dot(line.Look)
end

function AimLine.Lateral(line, position: Vector3): number
	return planar(position - line.Origin):Dot(line.Side)
end

function AimLine.Gap(line, mob): number
	local lateral = AimLine.Lateral(line, mob.Root.Position)
	local axis = planar(mob.Root.CFrame.LookVector)
	local reach = if axis.Magnitude > 1e-3 then axis.Unit:Dot(line.Side) * mob.Body.HalfLength else 0
	local front, back = lateral + reach, lateral - reach

	if front * back <= 0 then return -mob.Body.Radius end

	return math.min(math.abs(front), math.abs(back)) - mob.Body.Radius
end

function AimLine.Clear(line, mob, settings): Vector3
	local lateral = AimLine.Lateral(line, mob.Root.Position)
	local sign = math.sign(lateral)

	if math.abs(lateral) <= Config.Projectile.CenterBand then
		sign = if math.random() < 0.5 then -1 else 1
	end

	local needed = mob.Body.Radius + settings.margin - sign * lateral

	return mob.Root.Position + line.Side * sign * math.max(settings.distance, needed)
end

return AimLine
