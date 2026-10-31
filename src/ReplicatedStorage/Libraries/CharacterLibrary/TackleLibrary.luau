local TackleLibrary = {
	Cooldown = 3,
	CooldownLeniency = 0.2,

	Status = "IsTackling",
	ArmedStatus = "IsRunJumping",

	FacingSource = "Tackle",
	ImpulsePriority = 3,
	ForcePerMass = 4e4,
	LiftName = "@tackle_lift",

	Animations = {
		Dive = "TackleDive",
		Miss = "TackleMiss",
	},

	TrackPriority = Enum.AnimationPriority.Action4,
	TrackFade = 0.08,
	StopFade = 0.15,

	Leap = {
		Speed = 35,
		CruiseSpeed = 42,
		Drag = 2.5,

		Lift = 14,
		MaxRise = 24,

		Gravity = 0.8,
		SteerRate = 10,

		TrackSpeed = 1,
		MinFlight = 0.1,
		MaxFlight = 2.5,
	},

	Miss = {
		SkidTime = 0.55,
		SkidCurve = 2,
		TrackSpeed = 1,
		ProneHold = 0.2,
		GetUpFade = 0.35,
	},

	Hitbox = {
		shape = "Box",
		size = Vector3.new(5, 6, 5),
		offset = Vector3.new(0, -1, -2.5),
		max_targets = 1,
	},

	Grapple = {
		Name = "TackleGrapple",
		Spacing = 2,
		Duration = 5,

		IntroFade = 0.05,
		LoopFade = 0.2,
		ReleaseFade = 0.3,

		ConfirmWindow = 1,

		Attacker = {
			Status = "IsGrappling",
			Intro = "TackleHitAttacker",
			Loop = "TackleHitAttackerLoop",
		},

		Victim = {
			Status = "IsGrappled",
			Intro = "TackleHitVictim",
			Loop = "TackleHitVictimLoop",
		},
	},

	Report = {
		MaxAge = 0.5,
		MaxDistance = 14,
	},
}

return TackleLibrary
