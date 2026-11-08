local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

local entry: MorphTypes.Entry = {
	mob = "Wolf", --@ MobLibrary entry it borrows its rig, health, speeds, clips, bites and visuals from

	walk_speed = nil, --@ Studs/s without Run held; nil keeps the mob's, so footsteps line up with the real gait
	run_speed = nil, --@ Studs/s with Run held; nil keeps the mob's
	jump = 45, --@ JumpPower of the upward push on Space; there is no jump clip yet
	land_animation = "LeapLand", --@ Played on a heavy landing, which roots it like a player's

	dash = { --@ Hop in the held move direction (back when standing still); the clip comes from the mob's dash.animations
		distance = 16, --@ Studs it covers
		speed = nil, --@ nil keeps the mob's dash.speed
		cooldown = 0.5, --@ Seconds after landing before it may dash again
	},

	controls = { --@ Action -> inputs; each action is a MorphHandler/Actions module found by name
		Bite = { Enum.UserInputType.MouseButton1 }, --@ The mob's bite combo, hits landing on its windups; hold to keep biting
		Dash = { Enum.KeyCode.Q },
		Run = { Enum.KeyCode.LeftShift }, --@ Held
	},

	abilities = nil, --@ Mob abilities handed out as Tools, in hotbar order; clicking with one equipped uses it on the mob's own spec, leap and cooldown (a leap locks onto a target ahead within the ability's range). nil gives every ability the mob has, sorted by name

	shots = { --@ The number keys after the ability tools' slots, in this order: play a clip and its visual to line up SFX and VFX
		{ animation = "Growl" }, --@ A MobLibrary animations key or a clip name in Storage.Animations.Mobs.<mob>
		{ animation = "Howl" },
		{
			animation = "Screech",
			visual = "Screech", --@ Method on the mob's visuals module, played with the clip
			hold = { attribute = "IsScreeching", from = "Begin", to = "End", visual = "ScreechShake" }, --@ Attribute set between these markers (the whole clip without them), with a visual at its start
		},
		{ animation = "Inspect" },
		{ animation = "Eat", visual = "Eat", hold = { attribute = "IsFeeding" } },
		{ animation = "ClawingBitingCombo", visual = "Maul" },
		{ animation = "GrabThrow" },
		{ animation = "Hurt1" },
	} :: { MorphTypes.Shot },
}

return entry
