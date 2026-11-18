--[[@
	**Frog**: a swamp hunter that whips and spits its tongue up close and latches onto players
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `attack`: the whip-then-tongue combo
	  - `abilities/latch`: a leap onto the player's face, held by `FrogLatch`
	  - `abilities/tongue_latch`: the tongue grabs from range, held by `FrogTongueLatch`; winning it pulls the frog on into `latch`
	  - `tempo`: short flurries broken up by strafes, back-offs and hops, plus backing out to leap
	  - `animations`: clip names
	- **Brain:** the shared `Hunter` tree; it takes turns with any mob fighting the same player (`pack`)
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "Frog", --@ ServerStorage.Mobs model, authored at scale 1 and kept as is
	health = 60,
	walk_speed = 8,
	run_speed = 24,
	spawn = { group = { 1, 2 }, spread = 8 },

	pack = { --@ Takes turns at the lead with any mob on the same player; the rest comes from Defaults
		orbit_radius = 14, --@ Rings the player inside leaping distance while it waits its turn
		retreat_speed = 10,
	},
	rally = false,
	pounce = false, --@ It has no pounce clip; it runs in to close distance and leaps with `abilities/latch`
	sight = { eye_height = 0.8, hear_range = 14 },

	dash = {
		visual = "Dash", --@ FrogVisuals jump and landing dust per dash
	},

	visuals = "Combat.Mobs.FrogVisuals", --@ Effects module for every timeline the submodules name

	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One at random per hit taken

	animation_exclusive = { --@ Mirrored strafes never blend
		{ "WalkLeft", "WalkRight" },
	},
}
