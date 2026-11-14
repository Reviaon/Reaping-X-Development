--[[@
	**Bite combo**: four bites played in order, each with a small surge forward
	- **Windups:** each clip's visual frame / 60, so hits land with the visuals
	- **Step-in:** eases in and out, so a bite never snaps forward or stops dead
	- **Fourth bite:** a short lunge whose hit hands off to `abilities/leap_grab`'s grab and throw, through a block
]]
return {
	speed = 1.2,
	damage = 12,
	reach = 14, --@ Studs ahead of the root
	radius = 5, --@ Studs around the reach line
	recovery = 0.12, --@ Short, keeping the rhythm
	step_in = 24, --@ Peak studs/s, about 2 studs per surge
	step_in_lead = 0.3, --@ Seconds before the bite lands
	step_in_rise = 0.35, --@ Share eased in
	step_in_ease = 2, --@ Ease-out exponent
	animations = { "Bite1", "Bite2", "Bite3", "Bite4" }, --@ One per bite, in order

	combo = {
		[1] = { windup = 29 / 60 },
		[2] = { windup = 28 / 60 },
		[3] = { windup = 32 / 60 },
		[4] = {
			windup = 24 / 60,
			recovery = 0.8,
			radius = 6,
			leap = {
				delay = 14 / 60, --@ Seconds in, just before the bite is thrown
				speed = 30, --@ Far less than the leap grab's jump
				overrun = 1.5, --@ Studs eased on past the landing
				lead = 0.2, --@ Seconds of target movement aimed ahead
				track = 120, --@ Degrees/s it bends toward the target
			},
			grab = "leap_grab", --@ Ability whose grab and throw a hit plays
			unblockable = true,
		},
	},
}
