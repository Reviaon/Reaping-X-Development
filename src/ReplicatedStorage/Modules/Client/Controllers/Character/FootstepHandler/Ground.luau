local Config = require("./Config")
local Types = require("./Types")

local Ground = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

local function colorOf(result: RaycastResult): Color3
	local instance = result.Instance

	if instance:IsA("Terrain") then
		local ok, color = pcall(instance.GetMaterialColor, instance, result.Material)
		return if ok then color else Color3.new(0.5, 0.5, 0.5)
	end

	return (instance :: BasePart).Color
end

function Ground.Ignore(list: { Instance })
	params.FilterDescendantsInstances = list
end

function Ground.Under(position: Vector3): Types.Ground?
	local result = workspace:Raycast(position + Vector3.yAxis * Config.RayUp, Vector3.yAxis * -(Config.RayUp + Config.RayDepth), params)
	if not result then return nil end

	local instance = result.Instance

	return {
		Position = result.Position,
		Normal = result.Normal,
		Material = result.Material,
		MaterialVariant = if instance:IsA("BasePart") and not instance:IsA("Terrain") then instance.MaterialVariant else "",
		Color = colorOf(result),
		Kind = Config.Materials[result.Material] or Config.Fallback,
	}
end

return Ground
