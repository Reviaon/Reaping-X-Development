--[[@
	**Fit**: a set model ready to wear, cached once per model
	- **Pieces** come from `Layout` exactly as authored: their own size, at their offset from their limb model's `Centre`
	- Nothing is widened or rescaled, so a set fits a player the way it sits on its example R6 rig
]]
local Layout = require("./Layout")
local Types = require("./Types")

type Set = Types.Set

local Fit = {}

local Cache: { [Model]: Set } = {}

function Fit.Get(model: Model): (Set?, string?)
	local cached = Cache[model]
	if cached then return cached, nil end

	local placed, problem = Layout.Read(model)
	if not placed then return nil, problem end

	if problem then
		warn(`[ClothingService] {problem}`)
	end

	local set: Set = { Name = model.Name, Pieces = placed }
	Cache[model] = set

	return set, nil
end

return Fit
