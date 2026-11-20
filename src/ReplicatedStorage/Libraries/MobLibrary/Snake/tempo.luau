--[[@
	**Tempo**: a strike or two, then it sways round the player in its raised stance or backs off
	- **Breathers:** strafe (`Attack Stance E`), walk back (`Attack Stance S`) or a quick slither back (`dash.retreat`)
]]
return {
	flurry = { 1, 2 },
	moves = { strafe = 0.5, back = 0.35, dash = 0.15 },
	strafe = {
		time = { 0.8, 1.6 },
		step = 35,
		speed = "walk_speed",
	},
	back = {
		distance = { 3, 6 },
		speed = "walk_speed",
	},
	setup = false,
}
