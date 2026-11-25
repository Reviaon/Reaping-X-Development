--[[@
	**Grass footsteps**: a player's steps on grass
	- **Found by:** `Footsteps.Grass.Walk` / `Footsteps.Grass.Run`
	- **Cycle:** the variants were made to play in numbered order, so each body steps 1, 2, 3, 4, 1, … rather than at random
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Grass: SoundTypes.Group = {
	Walk = { Ids = { 92244985083848, 100614719075040, 91846989954708, 70865822950247 }, Cycle = true }, --@ Grass walk 1–4
	Run = { Ids = { 84395979548185, 76765713944619, 99435215266538, 129158033908717 }, Cycle = true }, --@ Grass run 1–4
}

return Grass
