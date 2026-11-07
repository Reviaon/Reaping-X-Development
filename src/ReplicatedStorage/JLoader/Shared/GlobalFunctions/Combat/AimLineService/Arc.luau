local Arc = {}

function Arc.At(origin: Vector3, velocity: Vector3, gravity: Vector3, t: number): Vector3
	return origin + velocity * t + gravity * (0.5 * t * t)
end

function Arc.VelocityAt(velocity: Vector3, gravity: Vector3, t: number): Vector3
	return velocity + gravity * t
end

function Arc.Caster(origin: Vector3, velocity: Vector3, gravity: Vector3, params: RaycastParams?)
	return function(from: number, to: number): (RaycastResult?, number)
		local a = Arc.At(origin, velocity, gravity, from)
		local b = Arc.At(origin, velocity, gravity, to)
		local result = workspace:Raycast(a, b - a, params)
		if not result then return nil, to end

		local length = (b - a).Magnitude
		return result, from + (to - from) * (if length > 0 then result.Distance / length else 0)
	end
end

function Arc.Trace(duration: number, steps: number, cast): (number, RaycastResult?)
	local from = 0

	for i = 1, steps do
		local to = if i == steps then duration else duration * i / steps
		local result, at = cast(from, to)

		if result then return at, result end

		from = to
	end

	return duration, nil
end

local function frame(position: Vector3, axis: Vector3): CFrame
	local reference = if math.abs(axis.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local back = axis:Cross(reference).Unit
	return CFrame.fromMatrix(position, axis, back:Cross(axis).Unit)
end

local function unit(vector: Vector3): Vector3
	return if vector.Magnitude > 0 then vector.Unit else Vector3.zAxis
end

function Arc.Bezier(origin: Vector3, velocity: Vector3, gravity: Vector3, t: number): (CFrame, CFrame, number, number)
	local exit = Arc.VelocityAt(velocity, gravity, t)

	return frame(origin, unit(velocity)),
		frame(Arc.At(origin, velocity, gravity, t), unit(exit)),
		velocity.Magnitude * t / 3,
		exit.Magnitude * t / 3
end

return Arc
