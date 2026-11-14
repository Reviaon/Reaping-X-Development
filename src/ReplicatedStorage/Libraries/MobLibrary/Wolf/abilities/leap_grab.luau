--[[@
	**Leap grab**: a long leap from the fight's edge; a hit grabs and throws, a miss lands
	- **Who:** any packmate, circling ones included, and a fresh aggro may open with it
	- **Leap:** covers any gap in `airtime`, bends toward the target, then eases on past the landing
	- **Hit:** the `WolfGrab` PairScene holds the player on the jaw, then throws them left, ragdolled
	- **Shared:** the fourth bite (`attack`) and the maul's win (`abilities/maul`) both play this grab by key
]]
return {
	min_range = 30, --@ Studs root to root
	range = 55,
	users = {
		passive = true, --@ Circling packmates may use it
		fresh = 3, --@ Seconds after aggro it may open with it
	},

	ability_cooldown = 15, --@ Seconds, this wolf
	team_cooldown = 12, --@ Seconds, any packmate on the same player
	chance = 0.4, --@ Per check
	retry = 2, --@ Seconds before rolling again
	animation = "Leap",
	miss_animation = "LeapLand",
	windup = 0.95, --@ Seconds into the clip it lands
	recovery = 1.1,
	radius = 6,

	leap = {
		delay = 0.45, --@ Seconds into the clip it leaves the ground
		airtime = 0.5, --@ Seconds, whatever the distance
		max_speed = 80,
		overrun = 10, --@ Studs eased on past the landing
		settle = 0.3, --@ Least seconds the overrun lasts; faster leaps carry further
		lead = 0.45, --@ Seconds of target movement aimed ahead
		track = 120, --@ Degrees/s it bends while airborne; 0 flies straight
	},

	cinematic = {
		Name = "WolfGrab",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 12, --@ Studs from the held player to its root
		Duration = 1.0, --@ Seconds held before the throw (Grab clip is 1.08s)
		IntroFade = 0.05,
		LoopFade = 0.15,
		ReleaseFade = 0.3,
		TimeoutOutcome = "Throw",

		BreakOn = {}, --@ The hold ragdolls the player on purpose
		Attacker = { Intro = "Grab" },

		Victim = {
			Status = "IsGrappled",
			Ragdoll = 3.2, --@ Seconds, through the release
			Follow = {
				Bone = "Bone18", --@ The lower jaw
				Offset = CFrame.new(0, -1.5, -1.5) * CFrame.Angles(0, 0, math.rad(90)), --@ Ahead of and below the jaw, crosswise
			},
		},
		Outcomes = {
			Throw = {
				Attacker = "M1s_Grab n throw",
				Launch = { Victim = true },
				ReleaseAt = { Victim = 1.9 }, --@ Seconds into the throw clip
			},
		},
		Throw = {
			Direction = "Left", --@ Relative to the wolf
			Damage = 18,
			Launch = {
				speed = 40, --@ Studs/s sideways
				lift = 50, --@ Studs/s up: about 6 studs, half a second airborne
				ragdoll = 1.5,
			},
		},
	},
}
