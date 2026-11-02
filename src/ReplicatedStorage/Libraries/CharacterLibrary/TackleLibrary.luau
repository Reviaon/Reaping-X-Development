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

	BackArc = 120,

	Grapples = {
		Front = {
			Name = "TackleGrapple",
			Facing = "Face",
			Spacing = 2,
			Bounds = { Min = Vector3.new(-2.8, -4.0, -5.4), Max = Vector3.new(2.8, 3.8, 7.7) },
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

		Back = {
			Name = "TackleGrappleBack",
			Facing = "Away",
			Spacing = 2,
			Bounds = { Min = Vector3.new(-3.0, -4.0, -7.1), Max = Vector3.new(3.0, 3.8, 5.4) },
			Duration = 5,

			IntroFade = 0.05,
			LoopFade = 0.2,
			ReleaseFade = 0.3,

			ConfirmWindow = 1,

			Attacker = {
				Status = "IsGrappling",
				Intro = "TackleHitAttackerBack",
				Loop = "TackleHitAttackerBackLoop",
			},

			Victim = {
				Status = "IsGrappled",
				Intro = "TackleVictimBack",
				Loop = "TackleHitVictimBackLoop",
			},
		},
	},

	Impact = {
		Variant = "Impact",
		ConfirmWindow = 1,
		Damage = 10,
		SkidCarry = 0.25,

		Launch = {
			ragdoll = 1.2,
			recovery = 0,
			speed = 34,
			lift = 0,
			spin = 0,
			twist = 0,
			flail = 0,
		},
	},

	Report = {
		MaxAge = 0.5,
		MaxDistance = 14,
	},
}

return TackleLibrary
