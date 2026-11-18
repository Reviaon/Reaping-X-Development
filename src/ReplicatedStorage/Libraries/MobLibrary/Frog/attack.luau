--[[@
	**Combo**: a tongue whip, then a quick straight tongue poke that reaches further
	- **Windups:** the clips' own named keyframes (`Hit`@0.933 in the whip, `Tongue Attack`@0.783 in the strike)
	- **Recovery:** until the tongue is back in, so the next swing never starts with it still out
]]
return {
	damage = 8,
	reach = 3, --@ Studs ahead of the root
	reach_height = 2, --@ The frog's root is a player's knee height; this lifts the hit line to their chest
	radius = 3,
	animations = { "Whip", "Tongue" }, --@ One per hit, in order

	combo = {
		[1] = { windup = 0.933, recovery = 0.55 },
		[2] = {
			speed = 2.5, --@ A quick poke: the hit lands at 0.31s; the tongue latch plays the same clip at normal speed
			windup = 0.783,
			recovery = 1.35, --@ The tongue holds out until 2.12s
			reach = 6, --@ The tongue snaps out 5 studs ahead
			radius = 2,
			damage = 10,
		},
	},
}
