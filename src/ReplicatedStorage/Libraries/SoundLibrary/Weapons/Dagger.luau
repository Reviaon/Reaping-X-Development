--[[@
	**Dagger**: the Dagger's swings and hits
	- **Found by:** `Weapons.Dagger.Whiff` / `Weapons.Dagger.Hit`
	- **By attack:** each attack in the combo plays the sound with its number
	- **Trim:** whiff 2's swoosh lands ~0.4 s in, so it starts there
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Dagger: SoundTypes.Group = {
	Whiff = { Ids = { 76740963409728, 87300508738846, 121049694294432, 88306502606110, 125264149259804 }, Volume = 0.4, Trim = { [87300508738846] = 0.36 } }, --@ Dagger whif 1–4, Dagger whiff 5
	Hit = { Ids = { 127827570984496, 87791908973470, 106996355531323, 79742638675673, 110832926717817 } }, --@ Dagger hit 1–5
}

return Dagger
