--[[@
	**MockingJay**: an alarm bird that gives survivors away and harries them with quick pecks
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `cry`: on spotting a player it screams; every mob in earshot turns on them, and players close by are stunned covering up
	  - `flight`: after the cry it takes off and skims round them at head height, landing now and then to cry again; with no one left to watch it lands
	  - `swoop` + `attack`: between cries it lands, walks in and pecks, then takes off again
  - `animations`: clip names; the `Engaged` keys are the flight set
	- **Brain:** the `Alarm` tree, so of the hunter kit only `attack` is used, through `swoop` (no pounce, dash, pack or tempo)
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "MockingJay", --@ ServerStorage.Mobs model, authored at scale 1
	tree = "Alarm",
	health = 40,
	walk_speed = 9, --@ Hopping round home, and walking in to peck
	chase_speed = "walk_speed", --@ It walks the last stretch to a peck rather than running
	run_speed = 16,
	turn_speed = 8,

	detect_range = 60,
	lose_range = 120,
	wander_radius = 20,
	spawn = { group = { 1, 2 }, spread = 10 },

	rig = {
		floor = 0, --@ Its feet are on its authored RootPart; the body mesh's bounds reach 2.8 below them, which stood it 2.8 off the ground
	},

	sight = { eye_height = 3, hear_range = 20 },
	sneak = { notice = 6 },
	search = false,
	pounce = false,
	dash = false,
	pack = false,

	visuals = "Combat.Mobs.MockingJayVisuals",
	clip_visuals = { --@ Played as each clip starts and every time it loops
		CryStart = "Cry", --@ The cry burst and the scream
		CryLoop = "CryLoop",
		Peck = "Peck",
		Land = "Land",
		EngagedIdle = "WingFlap", --@ Dust off the floor under its wingbeat, on every flight clip at Fly Idle's `wi` timing
		EngagedWalk = "WingFlap",
		EngagedRun = "WingFlap",
		EngagedWalkBack = "WingFlap",
		EngagedWalkLeft = "WingFlap",
		EngagedWalkRight = "WingFlap",
	},

	idle_actions = { "Peck" }, --@ Pecks at the ground between hops
	idle_action_chance = 0.6,
	hurt_animations = {}, --@ No flinch clips
}
