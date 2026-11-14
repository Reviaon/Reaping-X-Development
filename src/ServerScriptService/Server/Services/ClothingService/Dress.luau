--[[@
	**Dress**: puts a fitted set on a character and takes it off
	- **Worn pieces** live in one Model named `Container` inside the character, so taking a set off is one destroy
	- **Each piece** is welded to its limb at its fitted offset, so it follows animations and ragdolls
	  - It's sized to the wearer's real limb: its `Fit` widening, times the limb's size over the slot's R6 size, around the limb's center
	  - It never collides, is queried or touched, and adds no mass
	  - Prefixed names keep it from shadowing a limb in a `FindFirstChild` search
	- **Missing limbs** are skipped, so a partial body wears what it can
	- **Covered limbs** stay visible unless `HideLimbs` is on; then they go fully transparent, decals and textures too
	  - Each original transparency is kept on the object and restored when the set comes off
	  - A piece with the `ShowLimb` attribute leaves its limb visible (a belt over a bare torso)
]]
local Config = require("./Config")
local Types = require("./Types")

type Fitted = Types.Fitted
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

local function along(axis: Vector3, scale: Vector3): number
	return math.abs(axis.X) * scale.X + math.abs(axis.Y) * scale.Y + math.abs(axis.Z) * scale.Z
end

local function sized(fitted: Fitted, limb: BasePart): (Vector3, CFrame)
	local scale = fitted.Scale * (limb.Size / fitted.Slot.Size)
	local rotation = fitted.Offset.Rotation
	local size = fitted.Source.Size * Vector3.new(
		along(rotation.XVector, scale),
		along(rotation.YVector, scale),
		along(rotation.ZVector, scale)
	)

	return size, CFrame.new(fitted.Offset.Position * scale) * rotation
end

function Dress.Strip(character: Model)
	local container = character:FindFirstChild(Config.Container)

	if container then
		container:Destroy()
	end

	for _, defaultClothing in character:GetChildren() do
		if defaultClothing:IsA("Shirt") or defaultClothing:IsA("Pants") then
			defaultClothing:Destroy()
		end
	end

	reveal(character)
end

function Dress.Wear(character: Model, set: Set): number
	Dress.Strip(character)

	local container = Instance.new("Model")
	container.Name = Config.Container

	local worn = 0

	for _, fitted in set.Pieces do
		local limb = character:FindFirstChild(fitted.Slot.Limb)
		if not limb or not limb:IsA("BasePart") then continue end

		local size, offset = sized(fitted, limb)
		local piece = fitted.Source:Clone()
		piece.Name = Config.PiecePrefix .. fitted.Source.Name
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.Size = size
		piece.CFrame = limb.CFrame * offset

		local weld = Instance.new("Weld")
		weld.Part0 = limb
		weld.Part1 = piece
		weld.C0 = offset
		weld.Parent = piece

		piece.Parent = container
		worn += 1

		if Config.HideLimbs and fitted.Source:GetAttribute(Config.ShowLimbAttribute) ~= true then
			hide(limb)
		end
	end

	container.Parent = character

	return worn
end

return Dress
