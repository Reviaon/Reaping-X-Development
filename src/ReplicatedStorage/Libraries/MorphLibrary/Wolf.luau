--[[@
	**Wolf morph**: lets a player play as the Wolf mob
	- **Borrowed from `MobLibrary/Wolf`:** rig, health, speeds, clips, bites, abilities and visuals; this entry only adds the player's feel
	- **Controls:** each action is a `MorphHandler/Actions` module found by name
	  - Bite: the mob's combo, held to keep biting
	  - Dash: a hop in the held move direction, or backwards when standing still
	  - Run: held
	- **Abilities:** handed out as Tools; clicking one runs it on the mob's own spec, leap and cooldown
	  - A leap locks onto a target ahead within the ability's range, capped by `leap_distance`
	- **Shots:** the number keys after the ability slots play a clip and its visual, for lining up SFX and VFX
]]
local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

local entry: MorphTypes.Entry = {
	mob = "Wolf", --@ MobLibrary entry

	walk_speed = nil, --@ Studs/s; nil keeps the mob's, so footsteps match its gait
	run_speed = nil, --@ Studs/s with Run held; nil keeps the mob's
	jump = 45, --@ JumpPower on Space; no jump clip yet
	land_animation = "LeapLand", --@ Heavy landing, which roots it like a player's

	dash = { --@ Clip from the mob's dash.animations
		distance = 16, --@ Studs
		speed = nil, --@ nil keeps the mob's dash.speed
		cooldown = 0.5, --@ Seconds after landing
	},

	bite = { --@ Morph-only feel on bites 1-3; the final bite surges as the mob's does
		lunge = 3, --@ Studs surged per bite, eased like the mob's step-in, stopping short of a tracked target
		track = 240, --@ Degrees/s turned toward the target
		cone = 60, --@ Degrees off facing it looks for a target
		range = 18, --@ Studs ahead it looks
	},

	leap_distance = { --@ Most studs per leap ability, by key; the AI's own leaps are uncapped
		leap_grab = 24,
		maul = 24,
	},

	controls = { --@ Action -> inputs
		Bite = { Enum.UserInputType.MouseButton1 },
		Dash = { Enum.KeyCode.Q },
		Run = { Enum.KeyCode.LeftShift },
	},

	abilities = nil, --@ Ability keys in hotbar order; nil gives every mob ability, sorted by name

	shots = {
		{ animation = "Growl" }, --@ A mob animations key, or a clip in Storage.Animations.Mobs.<mob>
		{ animation = "Howl" },
		{
			animation = "Screech",
			visual = "Screech", --@ Method on the mob's visuals module
			hold = { attribute = "IsScreeching", from = "Begin", to = "End", visual = "ScreechShake" }, --@ Attribute between the markers (whole clip without them), visual at its start
		},
		{ animation = "Inspect" },
		{ animation = "Eat", visual = "Eat", hold = { attribute = "IsFeeding" } },
		{ animation = "ClawingBitingCombo", visual = "Maul" },
		{ animation = "GrabThrow" },
		{ animation = "Hurt1" },
	} :: { MorphTypes.Shot },
}

return entry
