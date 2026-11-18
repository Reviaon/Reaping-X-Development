--[[@
	**Layout**: reads where each piece of a set sits on its limb
	- **Limb model:** a set's child Model named after a slot key (`LeftArm`) or the limb itself (`Left Arm`)
	- **Centre:** the limb model's `Centre` part stands exactly where the limb goes; its size is the limb the pieces were authored on
	- **Pieces:** every other BasePart in the limb model, each at its CFrame relative to the `Centre`
	- **Problems** (an unknown limb model, a missing `Centre`) skip that limb model and are reported, so the rest of the set still wears
]]
local Config = require("./Config")
local Types = require("./Types")

type Placed = Types.Placed

local Layout = {}

function Layout.LimbOf(name: string): string?
	local limb = Config.Slots[name]
	if limb then return limb end

	for _, candidate in Config.Slots do
		if candidate == name then return candidate end
	end

	return nil
end

function Layout.Read(model: Model): ({ Placed }?, string?)
	local placed: { Placed } = {}
	local problems: { string } = {}

	for _, group in model:GetChildren() do
		if not group:IsA("Model") then continue end

		local limb = Layout.LimbOf(group.Name)

		if not limb then
			table.insert(problems, `{group.Name} isn't a limb in Config.Slots`)
			continue
		end

		local centre = group:FindFirstChild(Config.Centre)

		if not centre or not centre:IsA("BasePart") then
			table.insert(problems, `{group.Name} has no {Config.Centre} part`)
			continue
		end

		for _, piece in group:GetChildren() do
			if piece == centre or not piece:IsA("BasePart") then continue end

			table.insert(placed, {
				Source = piece,
				Limb = limb,
				Base = centre.Size,
				Offset = centre.CFrame:ToObjectSpace(piece.CFrame),
			})
		end
	end

	local problem = if #problems > 0 then `{model.Name}: {table.concat(problems, "; ")}` else nil

	if #placed == 0 then
		return nil, problem or `{model.Name} has no limb models with pieces`
	end

	return placed, problem
end

return Layout
