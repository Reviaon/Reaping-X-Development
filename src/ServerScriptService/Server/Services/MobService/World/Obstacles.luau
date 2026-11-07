local Obstacles = {}

Obstacles.Settings = {
	SeeThrough = 0.95, --@ Parts at least this transparent don't block a sightline
	MaxHops = 4, --@ See-through parts a sightline may pass before it counts as blocked
}

local params = nil

function Obstacles.Params(): RaycastParams
	if params then return params end

	local world = workspace:WaitForChild("World")

	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = { world:WaitForChild("Live"), world:WaitForChild("Visuals") }

	return params
end

function Obstacles.Sightline(from: Vector3, to: Vector3, rayParams: RaycastParams?): boolean
	local settings = Obstacles.Settings
	local query = rayParams or Obstacles.Params()
	local origin = from

	for _ = 0, settings.MaxHops do
		local offset = to - origin
		if offset.Magnitude < 1e-3 then return true end

		local hit = workspace:Raycast(origin, offset, query)
		if not hit then return true end
		if hit.Instance.Transparency < settings.SeeThrough then return false end

		origin = hit.Position + offset.Unit * 0.05
	end

	return false
end

return Obstacles
