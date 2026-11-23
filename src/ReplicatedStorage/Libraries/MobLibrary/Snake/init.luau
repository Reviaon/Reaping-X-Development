--[[@
	**Snake**: an ambush hunter that lies on the ground, coils up hissing once it has prey, and strikes, latches on or constricts
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `stance`: coils up into the hissing attack stance on getting a target, uncoils back to the ground on losing it
	  - `attack`: the bite from the attack stance
	  - `abilities/latch_on`: from the ground, it bites forward and hangs on, wriggling, until the player shakes it off
	  - `abilities/constrict`: from the stance, it dashes forward, loops round the player and squeezes; winning the struggle chains into `abilities/crush`
	  - `abilities/crush`: it drops the player to the floor and chokes them, then lets go and they seize on the ground
	  - `lurk`: after the crush it keeps its distance from the seizing player and nips at them
	  - `tempo`: a bite or two, then it repositions round the player or backs off
	  - `ragdoll`: the body that ragdolls when it dies, or when a finisher or push knocks it down
	  - `animations`: clip names; the `Engaged` keys are the stance set
	- **Brain:** the shared `Hunter` tree
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "Snake", --@ ServerStorage.Mobs model, authored at scale 1 and kept as is
	health = 80,
	walk_speed = 8,
	run_speed = 22,
	detect_range = 30, --@ It lies in wait: only a player this close draws it; it closes in along the ground, then coils (`stance`)
	spawn = { group = { 1, 1 } },

	pack = { --@ Takes turns at the lead with any mob on the same player; the rest comes from Defaults
		orbit_radius = 13, --@ Just outside striking distance
		retreat_speed = 10,
	},
	rally = false,
	pounce = { --@ A fast slither at a player still out of reach, then straight into the bite
		windup = 0.1,
		duration = 0.4,
		speed = 40,
		min_range = 12,
		range = 24,
		chance = 0.35,
		cooldown = 5,
	},
	sight = { eye_height = 2, hear_range = 10 },
	sneak = { notice = 4 }, --@ A sneaking player can get right up to it before it notices

	dash = {
		speed = 30,
		visual = "Fast", --@ SnakeVisuals ground dust per dash
		animations = { Left = false, Right = "WalkRight", Back = "WalkBack" }, --@ Coiled, these resolve to the stance repositions (`EngagedWalkRight`/`Back`); on the ground there are no dash clips, so it just slithers; no left clip yet
		dodge = { chance = 0.25, distance = 9 },
		flank = { chance = 0.3, posture = "ground" }, --@ Round a blocking player it uncoils and slithers, facing its path, then coils up again
	},

	visuals = "Combat.Mobs.SnakeVisuals", --@ Effects module for every timeline the submodules name

	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One at random per hit taken; the stance flinches replace them while coiled
}
