--[[@
	**Sword**: the Sword's swings
	- **Found by:** `Weapons.Sword.Whiff`
	- **By attack:** attacks 2 and 3 play their numbered whiffs; attacks without one wrap round the list
	- **No hit sounds yet:** add a `Hit` list here when they're uploaded
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Sword: SoundTypes.Group = {
	Whiff = { Ids = { 112008350063521, 118430628237350 }, Numbers = { 2, 3 }, Volume = 0.4 }, --@ Sword whif 2, Sword whif 3
}

return Sword
