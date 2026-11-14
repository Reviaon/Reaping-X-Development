--[[@
	**Sleep**: some rabbits spawn asleep; a sleeper naps again at home once things are calm
	- **Asleep:** loops `loop`; it still notices predators within `wake_range`
	- **Waking:** plays `wake`, then bolts (`evade`); a hit cuts the wake-up short
	- **Napping again:** after `resettle` calm seconds a sleeper walks home and plays `lie` into `loop`
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local sleep: MobTypes.Sleep = {
	chance = 0.4, --@ Share of spawns that start asleep
	wake_range = 24, --@ Studs a noticed predator wakes it from
	wake_speed = 1, --@ Playback of the wake-up clip
	resettle = 25, --@ Calm seconds before a sleeper naps again; false stays awake once woken
	blend = 0.25, --@ Seconds before a clip ends that the next one takes over
	animations = { --@ Keys in `animations`
		lie = "SleepLie",
		loop = "SleepLoop",
		wake = "SleepWake",
	},
}

return sleep
