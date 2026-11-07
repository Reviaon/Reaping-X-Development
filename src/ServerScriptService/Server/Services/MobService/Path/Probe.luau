local Obstacles = require("../Obstacles")

local Probe = {}

function Probe.Clear(mob, goal: Vector3, distance: number, settings): boolean
	local body = mob.Body
	local origin = mob.Root.Position
	local flat = Vector3.new(goal.X - origin.X, 0, goal.Z - origin.Z)
	if flat.Magnitude < 1e-3 then return true end

	local reach = math.min(distance, body.HalfLength + body.Radius + settings.probe_range)

	return workspace:Spherecast(origin, body.Radius * settings.probe_scale, flat.Unit * reach, Obstacles.Params()) == nil
end

function Probe.Lane(nav, mob, goal: Vector3, distance: number, settings, now: number): boolean
	if nav.LaneAt and now - nav.LaneAt < settings.probe_interval then return nav.LaneClear end

	nav.LaneAt = now
	nav.LaneClear = Probe.Clear(mob, goal, distance, settings)

	return nav.LaneClear
end

return Probe
