--[[@
	**Constrict**: from the attack stance it dashes forward, bites, loops round the player and squeezes until they drop
	- **Dash forward:** `Lunge` (`Snake Constrict Dash`) while the snake slides `leap` toward the player; contact is the clip's `bite` frame (0.283s)
	- **On a hit:** the `SnakeConstrict` PairScene starts at that same frame (`StartAt`), with the authored pairing
	  - Snake: the rest of the dash, `Snake Constrict Wrap`, then the looped `Snake Constrict Loop`
	  - Player: `Player Constrict Bit` from its `bite` frame, `Player Constrict Wrap`, then the struggling `Player Constrict Loop`
	  - The clips were authored with both roots together, facing each other, the player's body ~7.8 studs out from their root
	  - So the scene stands the snake `Spacing` away, as when it bit, and shifts the victim's root onto the snake's: the body stays where it was bitten
- **Drop:** 1.5s into the squeeze loop the scene times out into `abilities/crush`, where the player struggles on the floor
- **On a miss:** the dash ends where it slid to and the snake carries on from its coil
]]
return {
	posture = "stance", --@ Only from the coil, where the dash clip starts
	min_range = 9, --@ Studs root to root; closer than this it bites instead
	range = 16, --@ The dash covers up to ~7 studs before the head lands
	chance = 0.3, --@ Per check
	retry = 2,
	ability_cooldown = 18,
	animation = "Lunge",
	windup = 0.283, --@ The `bite` frame both dash clips share
	recovery = 0.1,
	reach = 9, --@ Studs of the hit line ahead of the root; also where the dash stops short of the player
	reach_height = 2,
	radius = 2,
	leap = { --@ A flat slide along the ground, not a jump
		delay = 0.05,
		airtime = 0.23, --@ Lands with the head at the `bite` frame, whatever the distance
		max_speed = 60,
		lead = 0.15, --@ Seconds of player movement aimed ahead
		track = 90, --@ Degrees/s it bends after a sidestepping player
	},
	cast_visual = "Lunge", --@ SnakeVisuals: the dash streak at the clip's `Constrict Dash` keyframe
	visual = "Bite", --@ SnakeVisuals: the bite flash on the body as the scene starts

	cinematic = {
		Name = "SnakeConstrict",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 8.7, --@ Studs root to root it bit from: the head's 7.8 plus the 0.9 its authored root sits ahead of the mob root
		StartAt = 0.283, --@ Both first clips pick up at the `bite` frame the dash hit on
		LoopWith = "Victim",
		Duration = 2.683, --@ The dash's last 0.1s, the 1.08s wrap, then 1.5s of the squeeze loop
		TimeoutOutcome = "AttackerWins",
		IntroFade = 0.05,
		LoopFade = 0.1,
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 2 }, --@ Per tick
		HitTimes = { 1.2, 2.2 }, --@ Seconds into the scene; the clips carry no hit markers
		Attacker = {
			Intro = { "Snake Constrict Dash", "Snake Constrict Wrap" },
			Loop = "Snake Constrict Loop",
			Shift = CFrame.new(0.14, -0.36, -0.13), --@ Jae's hand placement on `Workspace.SnakeExamples.Constrict Loop`: the jaw in the player's left shoulder
		},
		Victim = {
			Status = "IsGrappled",
			Intro = { "Player Constrict Bit", "Player Constrict Wrap" },
			Loop = "Player Constrict Loop",
			Shift = CFrame.new(0, 0, -7.8), --@ Onto the snake's authored root; the clip carries the body back to where it stood
		},
		Outcomes = {
			AttackerWins = { Then = "crush" },
		},
	},
}
