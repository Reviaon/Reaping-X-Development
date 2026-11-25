--[[@
	**Push**: the shove, keyed like `CharacterLibrary.PushLibrary`
	- **Found by:** `Abilities.Push.Whiff` (missed) / `Abilities.Push.Hit` (landed)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Push: SoundTypes.Group = {
	Whiff = { Ids = { 83167837116465 } }, --@ Push whiff
	Hit = { Ids = { 83919725105815 } }, --@ Push hit
}

return Push
