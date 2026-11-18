--[[@
	**Tempo**: the frog breaks off after a short flurry instead of attacking back to back
	- **Flurry:** one or two combo hits, rolled each time, then a breather
	- **Breathers:** strafe left or right round the player, walk back, or hop back (`dash.retreat`), then it closes in again
	- **Setup:** inside the latch's `min_range` with the latch ready, it backs out to leaping distance and leaps on arrival
]]
return {
	flurry = { 1, 2 }, --@ Combo hits before it breaks off
	moves = { strafe = 0.45, back = 0.3, dash = 0.25 }, --@ Weights of each breather
	strafe = {
		time = { 0.8, 1.6 }, --@ Seconds it circles the player
		step = 35, --@ Degrees round the player it aims ahead each refresh
		speed = "walk_speed",
	},
	back = {
		distance = { 4, 8 }, --@ Studs it walks back, facing the player
		speed = "walk_speed",
	},
	setup = {
		ability = "latch", --@ The ability it makes room for
		chance = 0.5, --@ Per breather while too close for it
		margin = 3.5, --@ Studs past the ability's min_range it backs out to; it stops 1.5 short, so this keeps it clear of the edge
		speed = "walk_speed",
		hold = 3, --@ Seconds the next in-range check skips the ability's chance roll
	},
}
