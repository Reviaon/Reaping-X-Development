--[[@
	**Spear**: the Spear's thrusts and hits
	- **Found by:** `Weapons.Spear.Whiff` / `Weapons.Spear.Hit`
	- **By attack:** each thrust plays the sound with its number (`Numbers`); attack 2 has no hit of its own and wraps round the list
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Spear: SoundTypes.Group = {
	Whiff = { Ids = { 125219767724970, 130878163724394, 117408413678009 }, Volume = 0.4 }, --@ Spear whif 1–3
	Hit = { Ids = { 130223194517149, 123378024454349 }, Numbers = { 1, 3 } }, --@ Spr hit 1, Spr hit 3
}

return Spear
