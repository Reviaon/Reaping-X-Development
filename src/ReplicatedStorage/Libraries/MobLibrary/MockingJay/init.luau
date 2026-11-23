--[[@
	**MockingJay**: a friendly bird until it is hurt, then an alarm that gives its attacker away
	- **Two moods** in the `Alarm` tree: passive by default; alarmed while it holds a grudge (`threat`: a provoker whose threat hasn't faded)
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `greet`: passive, it visits players it notices: flies round them, lands, walks up and bows (a player may interact to answer the bow), tags along a moment
	  - `startle`: an attack that misses spooks it into flying off; a hit that lands sets off its alarm
	  - `cry`: alarmed, it screams; every mob in earshot turns on the attacker; players aren't stunned by it
	  - `flight`: alarmed, it harries the attacker from high up (`States/Alarm/Flit`), crying again on the wing and flying them down if they run
	  - `ragdoll`: the body that ragdolls when it dies, or when a finisher or push knocks it down (out of the air, too)
	  - `animations`: clip names; the `Engaged` keys are the flight set
	- **Mourning:** when a MockingJay dies, every one within `mourn.radius` turns on the killer and cries
	- **It never attacks:** its peck is an idle action, eating off the ground
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "MockingJay", --@ ServerStorage.Mobs model, authored at scale 1
	tree = "Alarm",
	health = 40,
	walk_speed = 9, --@ Hopping round home, and walking up to a player it visits
	run_speed = 16, --@ Catching up on `Ground Run` when it tags along on foot
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
	threat = {
		decay = 30, --@ Seconds a hit keeps it alarmed
	},
	mourn = {
		radius = 90,
	},
	pounce = false,
	dash = false,
	pack = false,

	visuals = "Combat.Mobs.MockingJayVisuals",
	clip_visuals = { --@ Played as each clip starts and every time it loops
		CryStart = "Cry", --@ The cry burst and the scream
		CryLoop = { visual = "CryLoop", every = 2 }, --@ Its emitters run 2s, longer than the loop
		FlyCry = { visual = "FlyCryLoop", every = 2 },
		Peck = "Peck",
		Land = "Land",
		EngagedIdle = { visual = "WingFlap", below = 6 }, --@ Dust off the floor under its wingbeat at Fly Idle's `wi` timing, only while it skims low (taking off, landing)
		EngagedWalk = { visual = "WingFlap", below = 6 },
		EngagedRun = { visual = "WingFlap", below = 6 },
		EngagedWalkBack = { visual = "WingFlap", below = 6 },
		EngagedWalkLeft = { visual = "WingFlap", below = 6 },
		EngagedWalkRight = { visual = "WingFlap", below = 6 },
	},

	idle_actions = { "Peck" }, --@ Eats, pecking at the ground between hops
	idle_action_chance = 0.6,
	hurt_animations = {}, --@ No flinch clips
}
