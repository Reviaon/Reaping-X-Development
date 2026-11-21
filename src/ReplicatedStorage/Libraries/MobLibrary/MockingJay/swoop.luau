--[[@
	**Swoop**: now and then, between cries, it drops out of the air to peck
	- **In order, quick:** `Land` (its lift starts high enough to touch down on the clip's `land` frame), walk in at `chase_speed`, one `attack` peck, then it takes off and circles again
	- **Rhythm:** the first run `first` seconds after it spots someone, then every `every` seconds; a cry falling due takes its turn first
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local swoop: MobTypes.Swoop = {
	first = { 2, 4 },
	every = { 5, 8 },
}

return swoop
