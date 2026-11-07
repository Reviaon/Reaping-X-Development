local Geometry = {}

function Geometry.Planar(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Geometry.AngleAround(center: Vector3, position: Vector3): number
	local offset = position - center
	return math.atan2(offset.Z, offset.X)
end

return Geometry
