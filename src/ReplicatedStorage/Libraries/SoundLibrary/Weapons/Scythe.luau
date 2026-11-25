--[[@
	**Scythe**: the Scythe's swings and hits
	- **Found by:** `Weapons.Scythe.Whiff` / `Weapons.Scythe.Hit`
	- **By attack:** each attack plays the sound with its number (`Numbers`); attacks without one wrap round the list
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Scythe: SoundTypes.Group = {
	Whiff = { Ids = { 77559965449682, 77559707351005, 113755876122721 }, Numbers = { 1, 2, 4 }, Volume = 0.4 }, --@ Scythe whiff 1, 2, 4
	Hit = { Ids = { 88847469333454, 93280239057334 }, Numbers = { 2, 3 } }, --@ Scythe hit 2, 3
}

return Scythe
