--[[@
	**Dress**: puts a fitted set on a character and takes it off
	- **Worn pieces** live in one Model named `Container` inside the character, so taking a set off is one destroy
	- **Each piece** is welded to its limb at its authored offset and size, so it follows animations and ragdolls
	  - It never collides, is queried or touched, and adds no mass
	  - Prefixed names keep it from shadowing a limb in a `FindFirstChild` search
	- **Missing limbs** are skipped, so a partial body wears what it can
	- **Covered limbs** stay visible unless `HideLimbs` is on; then they go fully transparent, decals and textures too
	  - Each original transparency is kept on the object and restored when the set comes off
	  - A piece with the `ShowLimb` attribute leaves its limb visible (a belt over a bare torso)
]]
local Config = require("./Config")
local Types = require("./Types")

type Set = Types.Set

local Dress = {}

local function surfacesOf(limb: BasePart): { BasePart | Decal | Texture }
	local surfaces: { BasePart | Decal | Texture } = { limb }

	for _, child in limb:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			table.insert(surfaces, child)
		end
	end

	return surfaces
end

local function hide(limb: BasePart)
	for _, surface in surfacesOf(limb) do
		if surface:GetAttribute(Config.HiddenAttribute) ~= nil then continue end

		surface:SetAttribute(Config.HiddenAttribute, surface.Transparency)
		surface.Transparency = 1
	end
end

local function reveal(character: Model)
	for _, surface in character:GetDescendants() do
		if not (surface:IsA("BasePart") or surface:IsA("Decal") or surface:IsA("Texture")) then continue end

		local original = surface:GetAttribute(Config.HiddenAttribute)
		if typeof(original) ~= "number" then continue end

		surface.Transparency = original
		surface:SetAttribute(Config.HiddenAttribute, nil)
	end
end

function Dress.Strip(character: Model)
	local container = character:FindFirstChild(Config.Container)

	if container then
		container:Destroy()
	end

	reveal(character)
end

function Dress.Wear(character: Model, set: Set): number
	Dress.Strip(character)

	local container = Instance.new("Model")
	container.Name = Config.Container

	local worn = 0

	for _, placed in set.Pieces do
		local limb = character:FindFirstChild(placed.Limb)
		if not limb or not limb:IsA("BasePart") then continue end

		local offset = placed.Offset
		local piece = placed.Source:Clone()
		piece.Name = Config.PiecePrefix .. placed.Source.Name
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CFrame = limb.CFrame * offset

		local weld = Instance.new("Weld")
		weld.Part0 = limb
		weld.Part1 = piece
		weld.C0 = offset
		weld.Parent = piece

		piece.Parent = container
		worn += 1

		if Config.HideLimbs and placed.Source:GetAttribute(Config.ShowLimbAttribute) ~= true then
			hide(limb)
		end
	end

	container.Parent = character

	return worn
end

return Dress
