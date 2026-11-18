--[[@
	**Clothing config**: where sets live and how their limb models map onto an R6 body
	- **Sets:** each Model in `ServerStorage.<Folder>` is one set, worn by its name; a new set is a new model, no code
	- **Choice:** saved in the player's data at `Save`; `Default` until they choose
	- **Limb models:** a set's child Models are named after a slot below (or the limb itself, `Left Arm`)
	  - Each holds a `Centre` part standing exactly where that R6 limb goes, plus any number of pieces (a shirt and a belt on `Torso`)
	- **Layout:** each piece is worn exactly as authored, its own size at its offset from its limb model's `Centre`; nothing is rescaled
	  - Author a set on an R6 rig with each `Centre` on its limb; it fits players exactly as it sits there
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

	Slots = { --@ Limb model name -> the character limb its pieces weld to
		Torso = "Torso",
		Head = "Head",
		LeftArm = "Left Arm",
		RightArm = "Right Arm",
		LeftLeg = "Left Leg",
		RightLeg = "Right Leg",
	},
} :: Types.Config
