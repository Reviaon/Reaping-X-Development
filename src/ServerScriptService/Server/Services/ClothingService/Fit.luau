--[[@
	**Fit**: a set model ready to wear, cached once per model
	- **Offsets** come from `Layout`
	- **Widening** is each piece's baked `FitScale`, or measured now when it has none
	  - An unreadable mesh is worn unwidened, with a warning
]]
local Config = require("./Config")
local Layout = require("./Layout")
local Measure = require("./Measure")
local Types = require("./Types")

type Fitted = Types.Fitted
type Set = Types.Set

local Fit = {}

local Cache: { [Model]: Set } = {}

function Fit.Get(model: Model): (Set?, string?)
	local cached = Cache[model]
	if cached then return cached, nil end

	local placed, problem = Layout.Read(model)
	if not placed then return nil, problem end

	local pieces: { Fitted } = {}

	for _, piece in placed do
		local baked = piece.Source:GetAttribute(Config.ScaleAttribute)
		local scale = if typeof(baked) == "Vector3" then baked else Measure.Scale(piece)

		if not scale then
			warn(`[ClothingService] Couldn't read {model.Name}.{piece.Source.Name}'s mesh; it's worn unfitted. Bake it in Studio.`)
		end

		table.insert(pieces, {
			Source = piece.Source,
			Slot = piece.Slot,
			Offset = piece.Offset,
			Scale = scale or Vector3.one,
		})
	end

	local set: Set = { Name = model.Name, Pieces = pieces }
	Cache[model] = set

	return set, nil
end

return Fit
