local Obstacles = {}

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

return Obstacles
