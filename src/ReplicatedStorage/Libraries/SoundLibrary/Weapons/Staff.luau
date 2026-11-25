--[[@
	**Staff**: the Staff's swings and hits
	- **Found by:** `Weapons.Staff.Whiff` / `Weapons.Staff.Hit`
	- **By attack:** each attack plays the sound with its number (`Numbers`); attacks without one wrap round the list
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Staff: SoundTypes.Group = {
	Whiff = { Ids = { 123033746334881 }, Numbers = { 4 }, Volume = 0.4 }, --@ Staff whiff 4
	Hit = { Ids = { 119601341112165, 131890314338340, 82613512426218 }, Numbers = { 1, 2, 4 } }, --@ Staff hit 1, 2, 4
}

return Staff
