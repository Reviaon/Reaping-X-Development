--[[@
	**Stinger dash**: it winds back, then darts at the player stinger-first
	- **Timing:** the clip's `Hit1` keyframe (0.933s, frame 56); the charge starts at frame 27 (0.45s)
	- **Dash:** a flat `leap` from the charge to the hit, so it closes the gap rather than stinging on the spot
]]
return {
	damage = 14,
	reach = 10,
	reach_height = -3.5, --@ Its root hovers 4.4 above a player's; this drops the hit line to their chest
	radius = 3,
	step_in = 0,
	animations = { "Dash" },

	combo = {
		[1] = {
			windup = 0.933,
			recovery = 0.3,
			range = 22, --@ Studs root to root it dashes from
			min_range = 13, --@ Closer than this it backs off first, so every sting is a dash
			leap = {
				delay = 0.45,
				airtime = 0.45,
				max_speed = 60,
				lead = 0.2,
				track = 60,
				overrun = 4,
			},
		},
	},
}
