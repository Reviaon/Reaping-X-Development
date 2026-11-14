--[[@
	**Layout**: reads where each piece of a set model sits on its limb
	- **Slot:** a piece's name picks its slot, either the slot key (`LeftArm`) or the limb itself (`Left Arm`)
	- **Body:** placed where the set's limb pieces say an R6 body stands, oriented like its largest `Torso` piece
	  - The set Model's `BodyOffset` attribute overrides the guess
	- **Offset:** each piece's CFrame relative to its limb's center
]]
local Config = require("./Config")
local Types = require("./Types")

type Slot = Types.Slot
type Placed = Types.Placed

local Layout = {}

function Layout.SlotOf(piece: BasePart): Slot?
	local slot = Config.Slots[piece.Name]
	if slot then return slot end

	for _, candidate in Config.Slots do
		if candidate.Limb == piece.Name then return candidate end
	end

	return nil
end

local function anchorOf(model: Model): BasePart?
	local torso = Config.Slots.Torso
	local best: BasePart? = nil

	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") or Layout.SlotOf(child) ~= torso then continue end

		if not best or child.Size.Magnitude > best.Size.Magnitude then
			best = child
		end
	end

	return best
end

local function bodyOf(model: Model, anchor: BasePart): CFrame
	local pinned = model:GetAttribute(Config.BodyAttribute)
	if typeof(pinned) == "CFrame" then return anchor.CFrame * pinned end

	local rotation = anchor.CFrame.Rotation
	local torso = Config.Slots.Torso
	local sum = Vector3.zero
	local count = 0

	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then continue end

		local slot = Layout.SlotOf(child)
		if not slot or slot == torso then continue end

		sum += child.Position - rotation * slot.Offset.Position
		count += 1
	end

	if count == 0 then return anchor.CFrame end

	return CFrame.new(sum / count) * rotation
end

function Layout.Read(model: Model): ({ Placed }?, string?)
	local anchor = anchorOf(model)
	if not anchor then return nil, `{model.Name} has no Torso piece to place the body by` end

	local body = bodyOf(model, anchor)
	local placed: { Placed } = {}

	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then continue end

		local slot = Layout.SlotOf(child)
		if not slot then continue end

		table.insert(placed, {
			Source = child,
			Slot = slot,
			Offset = (body * slot.Offset):Inverse() * child.CFrame,
		})
	end

	return placed, nil
end

return Layout
