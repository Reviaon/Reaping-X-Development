--[[@
	**Rabbit**: passive prey that hops around home, naps, and bolts from anything that comes close
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `evade`: who it runs from and how
	  - `sleep`: spawning asleep, the wake-up, napping again
	  - `animations`: clip names
	- **Brain:** the `Prey` tree, so none of the hunter kit (attack, pounce, dash, pack) is used and it is all switched off
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "Rabbit", --@ ServerStorage.Mobs model, authored at scale 0.6 and kept as is
	tree = "Prey",
	health = 20,
	corpse_time = 8,

	walk_speed = 6, --@ Hopping around home
	run_speed = 18, --@ Bolting; a sprinting player (30) only just gains on it
	acceleration = 70,
	deceleration = 60,
	turn_speed = 12,
	turn_responsiveness = 40,

	wander_radius = 22,
	wander_pause = { 1, 3.5 },
	home_radius = 3,
	return_run = 60,
	spawn = { group = { 2, 4 }, spread = 10 }, --@ Rabbits per zone spawn

	sight = { eye_height = 0.6, hear_range = 14 },
	search = false,
	pounce = false,
	dash = false,
	pack = false,

	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One at random per hit taken
}
