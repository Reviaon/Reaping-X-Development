--[[@
	**TrackerBee**: a giant hornet that rages on sight, darts stinger-first at its prey and latches onto their back
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `alert`: the rage on spotting prey (`Bee Rage Aggro`), before it hunts
	  - `attack`: the stinger dash (`Bee Startup Dash Attack`)
	  - `abilities/latch`: it flies onto the player's back and stings while they run in place, until they shake it off
	  - `ragdoll`: the body that ragdolls when it dies (it is too big to be knocked down)
	  - `animations`: clip names
	- **Brain:** the shared `Hunter` tree; it always flies at its authored height, so it needs no `flight`
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "TrackerBee", --@ ServerStorage.Mobs model, authored at scale 1.83 and kept as is
	health = 90,
	walk_speed = 12,
	run_speed = 30,
	spawn = { group = { 1, 2 } },

	sight = { eye_height = 6 },

	rig = {
		turn = 180, --@ The template's RootPart looks at its stinger; the head is the other way
	},

	pack = {
		orbit_radius = 18,
	},

	dash = {
		animations = { Left = "WalkLeft", Right = "WalkRight", Back = "WalkBack" }, --@ No dash clips: its hops use the flying strafes
	},

	visuals = "Combat.Mobs.TrackerBeeVisuals", --@ Effects module for every timeline the submodules name
	clip_visuals = { --@ Played as each clip starts and every time it loops
		Idle = "Hover", --@ Ground smoke under the hover
		Run = "Fly", --@ The speed streaks
	},

	hurt_animations = {}, --@ No flinch clips
}
