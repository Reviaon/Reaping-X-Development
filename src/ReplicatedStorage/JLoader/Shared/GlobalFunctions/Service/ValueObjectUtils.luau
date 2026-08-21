-- // Utility module for value object classes
local util = {}

-- // Variables
local values_map = {
	["nil"] = "StringValue",
	["boolean"] = "BoolValue",
	["BrickColor"] = "BrickColorValue",
	["CFrame"] = "CFrameValue",
	["Color3"] = "Color3Value",
	["number"] = "NumberValue",
	["Instance"] = "ObjectValue",
	["Ray"] = "RayValue",
	["string"] = "StringValue",
	["Vector3"] = "Vector3Value",
}

-- // PUBLIC Functions
function util.GetClassFromType(_type: string)
	return values_map[_type]
end

function util.ConvertTypeToClass(_type: string)
	return Instance.new(values_map[_type])
end

return util