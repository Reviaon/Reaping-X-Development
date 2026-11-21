--[[@
	**Latch**: the bee flies onto a player's back, wraps round them and stings while they run in place trying to shake it
	- **Fly-in:** `Bee Startup Latch` with a flat `leap`; contact is its `hit1` keyframe (1.15s, frame 69)
	- **Hit:** the `BeeLatch` PairScene, authored with both roots together
	  - Bee: `Bee Latch` into the looped `Bee Latch Run`
	  - Player: `Player Bee Latch Connect` into the looped `Player Bee Latch Run`
	  - The victim struggles (`Default` profile); every `HitTimes` tick stings for `Hit.Damage`
	- **Shaken off, or a draw:** `Bee Latch End` and it backs off (`dash.retreat`)
	- **The player fails:** `Bee Latch End`, the venom drops them (`Ragdoll`), and it backs off
]]
return {
	min_range = 8,
	range = 24,
	chance = 0.35, --@ Per check
	retry = 2,
	ability_cooldown = 16,
	animation = "LatchStart",
	cast_visual = "Latch", --@ TrackerBeeVisuals: the strike at `hit1`
	windup = 1.15, --@ The clip's `hit1` keyframe
	recovery = 0.1,
	reach = 6,
	reach_height = -3.5,
	radius = 3,
	leap = {
		delay = 0.55,
		airtime = 0.5,
		max_speed = 60,
		lead = 0.25,
		track = 90,
	},

	cinematic = {
		Name = "BeeLatch",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 0,
		LoopWith = "Victim",
		Struggle = "Default",
		IntroFade = 0.1,
		LoopFade = 0.1,
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 3 },
		HitTimes = { 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5 },
		Attacker = {
			Intro = "Bee Latch",
			Loop = "Bee Latch Run",
			Shift = CFrame.new(0, 0, 1.093), --@ Puts the authored RootPart on the player's root, as the pair was animated: the mob root already stands at its hover height, 4.35 above it, and sits 1.09 behind it
		},
		Victim = {
			Status = "IsGrappled",
			Intro = "Player Bee Latch Connect",
			Loop = "Player Bee Latch Run",
		},
		Outcomes = {
			AttackerWins = { Attacker = "Bee Latch End", Ragdoll = { Victim = 1.5 }, Retreat = true },
			AttackerLoses = { Attacker = "Bee Latch End", Retreat = true },
			Draw = { Attacker = "Bee Latch End", Retreat = true },
		},
	},
}
