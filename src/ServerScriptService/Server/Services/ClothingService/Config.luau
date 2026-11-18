--[[@
	**Clothing config**: where sets live, how their limb models map onto an R6 body, and how pieces are fitted to it
	- **Sets:** each Model in `ServerStorage.<Folder>` is one set, worn by its name; a new set is a new model, no code
	- **Choice:** saved in the player's data at `Save`; `Default` until they choose
	- **Limb models:** a set's child Models are named after a slot below (or the limb itself, `Left Arm`)
	  - Each holds a `Centre` part standing exactly where that R6 limb goes, plus any number of pieces (a shirt and a belt on `Torso`)
	- **Layout:** each piece keeps its authored offset from its limb model's `Centre`; the `Centre`'s size is the limb it was authored on
	- **Fit:** each piece is widened until the limb's side faces sit `Fit.Margin` inside it, then sized to the wearer's real limb
	  - `Measure.Bake()` stores the widening on each piece as `ScaleAttribute`; an unbaked piece is measured on first wear
	- **Hiding:** with `HideLimbs` on, limbs under a piece go transparent; a piece's `ShowLimbAttribute` keeps its limb visible
	- **Avatar:** with `StripAvatar` on, every `StripClasses` child of a player's body is removed on spawn and whenever one loads later
	  - Hair stays: accessories of a `KeepTypes` type, or carrying a `KeepAttachments` attachment
]]
local Types = require("./Types")

return {
	Folder = "Clothing", --@ ServerStorage folder of set models
	Container = "Clothing", --@ Model inside the character that holds the worn pieces
	PiecePrefix = "Clothing", --@ Prepended to piece names, so no worn piece shadows a limb name
	Centre = "Centre", --@ Part in each limb model marking where the limb stands
	ScaleAttribute = "FitScale", --@ Baked Vector3 widening on a piece, in its limb's axes
	HideLimbs = false, --@ Covered limbs go transparent while a set is worn
	HiddenAttribute = "ClothingTransparency", --@ A hidden limb's original transparency, restored when the set comes off
	ShowLimbAttribute = "ShowLimb", --@ Set true on a piece to leave its limb visible
	Default = "Set2M", --@ Set a player wears until they choose one; nil wears none
	OffWords = { off = true, none = true, remove = true },

	Save = { --@ Where the chosen set is saved in the player's data
		Scope = "Player", --@ DataService scope
		Path = { "CharacterData", "Outfit" }, --@ Table inside that scope's data
		Key = "Set", --@ String key holding the set name; "" saves none
		Timeout = 15, --@ Most seconds a spawn waits for the data to load before dressing from the default
	},

	StripAvatar = true, --@ Remove the player's own Roblox accessories and clothing from their body
	StripClasses = { "Accoutrement", "Shirt", "Pants", "ShirtGraphic" }, --@ Accoutrement covers every Accessory and Hat
	KeepTypes = { Enum.AccessoryType.Hair }, --@ Accessories of these types stay on
	KeepAttachments = { "HairAttachment" }, --@ Accessories whose Handle has one of these stay on, for older catalog hair typed Unknown

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

	Slots = { --@ Limb model name -> the character limb its pieces weld to
		Torso = "Torso",
		Head = "Head",
		LeftArm = "Left Arm",
		RightArm = "Right Arm",
		LeftLeg = "Left Leg",
		RightLeg = "Right Leg",
	},
} :: Types.Config
