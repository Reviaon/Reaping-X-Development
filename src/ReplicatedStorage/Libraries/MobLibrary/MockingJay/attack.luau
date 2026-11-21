--[[@
	**Peck**: the strike at the end of a swoop; it lands, walks in and pecks once
	- **Timing:** the clip's `peck` marker (frame 64, 1.067s), played 1.5x so the run is quick
	- **Reach:** a short jab ahead of the body at a player's legs
]]
return {
	speed = 1.5, --@ Clip and timings; the hit lands 0.71s in
	damage = 6,
	reach = 6, --@ With `radius`, covers the 7-7.5 studs it stops at after walking in
	reach_height = 0,
	radius = 2.5,
	step_in = 0,
	animations = { "Peck" },

	combo = {
		[1] = { windup = 64 / 60, recovery = 0.4, range = 8 }, --@ Root to root, in 3D: its root sits 1.2 above a player's, so 6 left it standing just out of range
	},
}
