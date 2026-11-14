--[[@
	**Rabbit morph**: lets a player play as the Rabbit mob
	- **Borrowed from `MobLibrary/Rabbit`:** rig, health, speeds and clips; this entry only adds the player's feel
	- **Controls:** each action is a `MorphHandler/Actions` module found by name
	  - Run: held
	  - No bite and no dash: the rabbit has neither
	- **Shots:** the number keys play the sleep clips and a flinch, for lining up SFX
]]
local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

local entry: MorphTypes.Entry = {
	mob = "Rabbit", --@ MobLibrary entry

	walk_speed = nil, --@ Studs/s; nil keeps the mob's, so the hop matches its gait
	run_speed = nil, --@ Studs/s with Run held; nil keeps the mob's
	jump = 40, --@ JumpPower on Space; no jump clip yet

	controls = { --@ Action -> inputs
		Run = { Enum.KeyCode.LeftShift },
	},

	shots = {
		{ animation = "SleepLie" }, --@ A mob animations key, or a clip in Storage.Animations.Mobs.<mob>
		{ animation = "SleepLoop" },
		{ animation = "SleepWake" },
		{ animation = "Hurt1" },
	} :: { MorphTypes.Shot },
}

return entry
