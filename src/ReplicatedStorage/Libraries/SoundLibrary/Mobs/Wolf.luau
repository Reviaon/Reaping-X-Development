--[[@
	**Wolf**: the wolf mob's own sounds, keyed like its `MobLibrary` entry
	- **Found by:** `Mobs.Wolf.<Name>`
	- **Walk:** paw steps, played in numbered order per wolf (`Cycle`)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Wolf: SoundTypes.Group = {
	Walk = { Ids = { 92271935423896, 102703608039386 }, Cycle = true }, --@ Wolf walk 3, Wolf walk 4
}

return Wolf
