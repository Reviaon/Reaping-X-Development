--[[@
	**Data config**: the profile stores players load and what each replicates
	- **Stores:** keyed by scope (`DataService:Open(player, "Player")`); a new scope is a new entry, plus an optional `Handlers/<Scope>` module
	- **Key:** `<Prefix><UserId>`; changing `Prefix` starts every player on fresh data
	- **Replicate:** names the Folder under the Player that mirrors the profile's data; nil keeps that scope server-only
]]
local TempData = require("@game/ReplicatedStorage/Libraries/DataLibrary/TempData")
local Types = require("./Types")

return {
	Prefix = "Reaping0.0.1_", --@ Profile key prefix, ahead of the UserId
	MockInStudio = false, --@ Studio sessions load a throwaway mock profile instead of real data

	Stores = {
		Player = {
			Name = "PlayerData", --@ DataStore name
			Template = TempData.plrData, --@ Reconciled into every profile
			Replicate = "Data", --@ Folder under the Player
		},
	},

	Classes = { --@ Lua type -> Instance class that mirrors it
		number = "NumberValue",
		string = "StringValue",
		boolean = "BoolValue",
		table = "Folder",
	},

	Kick = {
		Failed = "Your data couldn't be loaded. Please rejoin.",
		Released = "Your data was loaded in another server. Please rejoin.",
	},
} :: Types.Config
