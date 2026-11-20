--[[@
	**Bite from the attack stance**: the head shoots ~9 studs out of the coil and recoils
	- **Windup:** the clip's own `snake attack` keyframe (0.167s), where the head reaches full length
	- **Recovery:** until the head is back in the coil (0.94s), so it never bites again mid-recoil
	- **No step-in:** it bites from where it is coiled
]]
return {
	damage = 12,
	reach = 8, --@ Studs ahead of the root; the head lands 9 out
	reach_height = 2, --@ The struck head is 2.3 above the root: a player's chest
	radius = 2,
	step_in = 0,
	animations = { "Strike" },

	combo = {
		[1] = { windup = 0.167, recovery = 0.85 },
	},
}
