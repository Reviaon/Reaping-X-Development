--[[@
	**Latch on**: from the ground, at a player looking straight at it, the snake bites onto the middle of their torso, hangs there, then lets go
	- **Ground only:** `posture = "ground"`, so it is the ambush before the stance; `faced` keeps it for a player facing the snake
	- **Bite forward:** Jae's "Bite forward from Ground Idle" clip isn't in the uploaded set, so the stance bite (`Strike`, `snake attack`@0.167) stands in
	- **Hit:** the `SnakeLatch` PairScene plays `Snake LatchOn` over the victim's `Player LatchOn` once through, no loop and no struggle
	  - Same authored layout as `constrict`: roots together, facing each other, the body ~7.8 studs out
	  - `Attacker.Track` turns the snake about its root each frame so its jaw stays on the torso as the player fights it
	  - The snake lets go in the clips' last frames; the scene ends with them and the snake slithers back (`dash.retreat`)
]]
return {
	posture = "ground",
	faced = 60, --@ Degrees off the player's look the snake may sit
	min_range = 4,
	range = 10,
	chance = 0.5, --@ Per check
	retry = 3,
	ability_cooldown = 16,
	animation = "Strike",
	windup = 0.167,
	recovery = 0.4,
	reach = 8,
	reach_height = 2,
	radius = 2,
	cast_visual = "Strike", --@ SnakeVisuals: the strike streak
	visual = "Bite", --@ SnakeVisuals: the bite flash on the body as the scene starts

	cinematic = {
		Name = "SnakeLatch",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 9.5, --@ 0.8 further out than the coils, so the jaw lands on the middle of the torso's front, not inside it
		Duration = "Attacker", --@ Ends with `Snake LatchOn`, which lets go in its last frames
		TimeoutOutcome = "AttackerWins",
		IntroFade = 0.15,
		LoopFade = 0.15,
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 3 },
		HitTimes = { 0.3, 1.8, 3.3 },
		Attacker = {
			Intro = "Snake LatchOn", --@ No lift, unlike the coils: its body lies along the ground while the head bites the chest
			Track = { --@ The clip holds its head still while the player struggles and slumps, so the whole snake turns about its root to keep the jaw on them
				Bone = "Bone.020", --@ The jaw
				Part = "Torso",
				Point = Vector3.new(0, 0, -0.5), --@ The middle of the torso's front
				Angle = 15, --@ Most degrees it turns (yaw, then pitch)
				Slide = 1.5, --@ Most studs it slides along the line to the torso
			},
		},
		Victim = {
			Status = "IsGrappled",
			Intro = "Player LatchOn",
			Shift = CFrame.new(0, 0, -7.8),
		},
		Outcomes = {
			AttackerWins = { Retreat = true },
		},
	},
}
