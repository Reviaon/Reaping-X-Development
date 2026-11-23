--[[@
	**Frog**: a swamp hunter that whips and spits its tongue up close and latches onto players
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `attack`: the whip-then-tongue combo
	  - `abilities/latch`: a leap onto the player's face, held by `FrogLatch`
	  - `abilities/tongue_latch`: the tongue grabs from range, held by `FrogTongueLatch`; winning it pulls the frog on into `latch`
	  - `tempo`: short flurries broken up by strafes, back-offs and hops, plus backing out to leap
	  - `ragdoll`: the body that ragdolls when it dies, or when a finisher or push knocks it down
	  - `animations`: clip names
	- **Brain:** the shared `Hunter` tree; it takes turns with any mob fighting the same player (`pack`)
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "Frog", --@ ServerStorage.Mobs model, authored at scale 1 and kept as is
	health = 60,
	walk_speed = 7,
	run_speed = 21, --@ Frantic Run plays matched to this, so it slows with it
	spawn = { group = { 1, 2 }, spread = 8 },

	pack = { --@ Takes turns at the lead with any mob on the same player; the rest comes from Defaults
		orbit_radius = 14, --@ Rings the player inside leaping distance while it waits its turn
		retreat_speed = 10,
	},
	rally = false,
	pounce = { --@ Now and then mid-chase it hops at the player to close distance, then runs straight on
		animation = "Leap",
		windup = 0.067, --@ The clip's `Leap` keyframe: the hop leaves the ground here
		duration = 0.45, --@ Seconds in the air
		min_range = 10, --@ Only a real gap: closer than this it just runs in
		range = 22,
		chance = 0.3, --@ Per check while chasing in range
		retry = 1.2,
		cooldown = 4,
		lead = 0.3,
		stop = 5, --@ Lands this far short of the player, still running
		max_speed = 45,
		arc = {
			height = 2.5,
			hold = 0.15, --@ The clip's airborne pose: from here it is re-timed to land with the root
			resume = 0.75, --@ Clip time reached on landing, where it blends back into the run
			home = 10,
		},
	},
	sight = { eye_height = 0.8, hear_range = 14 },
	sneak = { notice = 4 }, --@ Short senses: a sneaking player can get close before it notices

	dash = { --@ Slippery: hops out of swings and combos and around a guard far more than the wolf
		visual = "Dash", --@ FrogVisuals jump and landing dust per dash
		dodge = {
			chance = 0.5, --@ Per swing aimed at it
			retry = 0.5,
			cooldown = 2.2,
			distance = 10,
			escape = 0.4, --@ Chance per hit it breaks out of a combo string
		},
		flank = {
			chance = 0.6,
			retry = 0.6,
			cooldown = 2.5,
			run_chance = 0.6, --@ Darts wide round the player instead of dashing
		},
	},

	visuals = "Combat.Mobs.FrogVisuals", --@ Effects module for every timeline the submodules name

	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One at random per hit taken

	animation_exclusive = { --@ Mirrored strafes never blend
		{ "WalkLeft", "WalkRight" },
	},
}
