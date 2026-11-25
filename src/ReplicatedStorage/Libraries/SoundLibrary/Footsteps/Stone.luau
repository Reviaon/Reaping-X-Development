--[[@
	**Stone footsteps**: a player's steps on stone
	- **Found by:** `Footsteps.Stone.Walk` / `Footsteps.Stone.Run`
	- **One variant each** so far; more ids drop straight into the lists and play in numbered order (`Cycle`)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Stone: SoundTypes.Group = {
	Walk = { Ids = { 113105407221699 }, Cycle = true }, --@ Stone walk 1
	Run = { Ids = { 73236835838353 }, Cycle = true }, --@ Stone run
}

return Stone
