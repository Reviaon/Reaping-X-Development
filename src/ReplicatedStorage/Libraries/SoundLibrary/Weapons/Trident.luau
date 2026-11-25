--[[@
	**Trident**: the Trident's swing and hit
	- **Found by:** `Weapons.Trident.Whiff` / `Weapons.Trident.Hit`
	- **By attack:** one sound each so far, played on every attack; numbered ones added later go to their own attack (`Numbers`)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Trident: SoundTypes.Group = {
	Whiff = { Ids = { 75148280502839 }, Numbers = { 1 }, Volume = 0.4 }, --@ Trident whiff 1
	Hit = { Ids = { 121540313847599 }, Numbers = { 2 } }, --@ Trident hit 2
}

return Trident
