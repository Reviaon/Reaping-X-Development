--[[@
	**Melee**: the fists' swings and hits, keyed like the `WeaponsLibrary.Melee` entry
	- **Found by:** `Weapons.Melee.Whiff` / `Weapons.Melee.Hit`
	- **By attack:** each attack in the combo plays the sound with its number; the 6th swing has no whiff of its own and plays whiff 1
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Melee: SoundTypes.Group = {
	Whiff = { Ids = { 83699156693167, 130442664689210, 79831645711815, 94404788188034, 86764283301956 }, Volume = 0.4 }, --@ Fist whiff 1–5
	Hit = { Ids = { 75250779689883, 74496499009154, 112187008285792, 128630755821194, 122457293594487, 121919602553542 } }, --@ Fist hit 1–6
}

return Melee
