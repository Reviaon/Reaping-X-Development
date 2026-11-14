--[[@
	**Clothing config**: where sets live, how their pieces map onto an R6 body, and how they're fitted to it
	- **Sets:** each Model in `ServerStorage.<Folder>` is one set, worn by its name; a new set is a new model, no code
	- **Pieces:** a MeshPart named after a slot below (or the limb itself, `Left Arm`) is welded to that limb
	  - Several pieces may share a slot (a coat and a belt both on `Torso`)
	- **Layout:** the body is placed where the set's limb pieces say it stands, then each piece keeps its authored offset from its limb
	  - A set Model's `BodyAttribute` (CFrame, relative to its largest `Torso` piece) pins the body by hand when the guess is off
	- **Fit:** each piece is widened until the limb's side faces sit `Fit.Margin` inside it, then sized to the wearer's real limb
	  - `Measure.Bake()` stores the widening on each piece as `ScaleAttribute`; an unbaked piece is measured on first wear
	- **Hiding:** with `HideLimbs` on, limbs under a piece go transparent; a piece's `ShowLimbAttribute` keeps its limb visible
]]
local Types = require("./Types")

return {
	Folder = "Clothing", --@ ServerStorage folder of set models
	Container = "Clothing", --@ Model inside the character that holds the worn pieces
	PiecePrefix = "Clothing", --@ Prepended to piece names, so no worn piece shadows a limb name
	Attribute = "ClothingSet", --@ Player attribute naming the set worn across respawns and morphs
	BodyAttribute = "BodyOffset", --@ Optional CFrame on a set Model
	ScaleAttribute = "FitScale", --@ Baked Vector3 widening on a piece, in its limb's axes
	HideLimbs = false, --@ Covered limbs go transparent while a set is worn
	HiddenAttribute = "ClothingTransparency", --@ A hidden limb's original transparency, restored when the set comes off
	ShowLimbAttribute = "ShowLimb", --@ Set true on a piece to leave its limb visible
	Default = nil, --@ Set a new player wears; nil wears none
	OffWords = { off = true, none = true, remove = true },

	Fit = {
		Margin = 0.04, --@ Studs of clothing kept outside each limb face
		Edge = 0.95, --@ Share of a face's width sampled, so the limb's corners are covered
		Rows = 11, --@ Samples along the limb's length
		Columns = 7, --@ Samples across each face
		Rim = 0.12, --@ Studs at a piece's top and bottom left unsampled, where hems turn inward
		Wall = 0.4, --@ Share of the half-width from a face where a hit counts as a wall inside the limb; deeper is an opening
		Facing = 0.5, --@ How squarely a hit triangle must face out of the limb face to count as a wall, not a seam or fold
		Reach = 2, --@ Studs past a face a covering wall is looked for
		MaxScale = 2, --@ Most a piece is widened on one axis
	},

	Slots = { --@ Piece name -> limb it welds to, that limb's R6 size, and its place relative to the Torso
		Torso = { Limb = "Torso", Size = Vector3.new(2, 2, 1), Offset = CFrame.identity },
		Head = { Limb = "Head", Size = Vector3.new(2, 1, 1), Offset = CFrame.new(0, 1.5, 0) },
		LeftArm = { Limb = "Left Arm", Size = Vector3.new(1, 2, 1), Offset = CFrame.new(-1.5, 0, 0) },
		RightArm = { Limb = "Right Arm", Size = Vector3.new(1, 2, 1), Offset = CFrame.new(1.5, 0, 0) },
		LeftLeg = { Limb = "Left Leg", Size = Vector3.new(1, 2, 1), Offset = CFrame.new(-0.5, -2, 0) },
		RightLeg = { Limb = "Right Leg", Size = Vector3.new(1, 2, 1), Offset = CFrame.new(0.5, -2, 0) },
	},
} :: Types.Config
