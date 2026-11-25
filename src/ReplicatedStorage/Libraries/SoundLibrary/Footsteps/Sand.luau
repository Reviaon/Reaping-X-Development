--[[@
	**Sand footsteps**: a player's steps on sand
	- **Found by:** `Footsteps.Sand.Walk` / `Footsteps.Sand.Run`
	- **Cycle:** the variants were made to play in numbered order, so each body steps 1, 2, 3, 1, … rather than at random
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Sand: SoundTypes.Group = {
	Walk = { Ids = { 107556603188025, 114408608098561, 123896971779903 }, Cycle = true }, --@ Sand walk 1–3
	Run = { Ids = { 136994393201920, 88278911814626, 117147905052890 }, Cycle = true }, --@ Sand run 1–3
}

return Sand
