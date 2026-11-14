return {
	--@ Seconds between pushes. The server holds the same number, less its own leniency
	Cooldown = 2,

	--@ True: a push moves a guarding victim like anyone else. False: the guard absorbs it as a hit
	ThroughGuard = true,

	TrackPriority = Enum.AnimationPriority.Action4,
	TrackFade = 0.1,

	--@ The one hit reaction a pushed victim plays, by name, out of their hit reaction set
	Reaction = "UniversalHitReaction3",

	--@ What either push does to its victim: launched back and ragdolled, the same distance whichever
	--@ way it was thrown. A finisher-shaped table
	Launch = {
		ragdoll = 1.2,
		recovery = 0.5,
		speed = 30,
		lift = 22,
		spin = 360,
	},

	HitStop = {
		Duration = 0.1,
		Punch = "Push",
	},

	GrabArc = 120,

	ClashWindow = 0.3,
	ClashArc = 120,
	ClashDistance = 8,

	Struggle = {
		Name = "PushStruggle",
		Struggle = "Default",
		Facing = "Face",
		Spacing = 2,
		Bounds = { Min = Vector3.new(-2.4, -3.4, -4.7), Max = Vector3.new(2.4, 2.1, 2.7) },
		Duration = 5,

		IntroFade = 0.15,
		LoopFade = 0.15,
		ReleaseFade = 0.3,

		Attacker = {
			Loop = "PushStruggleAttackerLoop",
		},

		Victim = {
			Loop = "PushStruggleVictimLoop",
		},

		LaunchDelay = 0.25,

		Outcomes = {
			AttackerWins = { Attacker = "Push" },
			AttackerLoses = { Victim = "Push" },
		},
	},

	Grab = {
		Name = "PushGrab",
		Struggle = "Default",
		Facing = "Away",
		Spacing = 2,
		Bounds = { Min = Vector3.new(-3.1, -3.7, -7.3), Max = Vector3.new(2.9, 2.9, 6.1) },
		Duration = 5,

		IntroFade = 0.05,
		LoopFade = 0.2,
		ReleaseFade = 0.3,

		Attacker = {
			Status = "IsGrappling",
			Intro = "GrabStartAttacker",
			Loop = "GrabStruggleAttackerLoop",
		},

		Victim = {
			Status = "IsGrappled",
			Intro = "GrabStartVictim",
			Loop = "GrabStruggleVictimLoop",
		},

		TimeoutOutcome = "Draw",

		HitTargets = { GrabFailAttacker = "Self" },

		Outcomes = {
			Draw = { Attacker = "GrabReleaseAttacker", Victim = "GrabReleaseVictim" },
			AttackerWins = { Attacker = "GrabSuccessAttacker", Victim = "GrabFailVictim", Launch = { Victim = true } },
			AttackerLoses = { Attacker = "GrabFailAttacker", Victim = "GrabEscapeVictim", Launch = { Attacker = true } },
		},
	},

	--@ Each variant:
	--@   Status      held on the pusher for Duration seconds; nothing else can be started under it
	--@   HitboxDelay seconds into the push the shove lands
	--@   Hitbox      same shape of table a weapon's hitbox is
	--@   Window      seconds from the start of the push the server still takes its hit

	--@ Pushed from a standstill or a walk
	Stand = {
		Animation = "Push",
		Weight = 1,
		Status = "IsPushing",
		Duration = 0.6,
		HitboxDelay = 0.25,
		Window = 1,

		Hitbox = {
			shape = "Box",
			size = Vector3.new(5, 5, 5),
			offset = Vector3.new(0, 0, -3),
			duration = 0.15,
			max_targets = 1,
			effect = "BluntHit",
		},

		--@ The pusher's own step forward, the same recipe a light attack's lunge is. delay is the
		--@ seconds into the push it starts; influence is the share of walk speed that stays live
		Impulse = {
			delay = 0.25,
			speed = 6,
			duration = 0.3,
			falloff = 0.2,
			rampIn = 0.06,
			influence = 0.5,
			priority = 1,
		},

	},

	--@ Pushed out of a sprint. MinSpeed is the studs per second the server must see the pusher
	--@ moving at when the push starts or lands; under it the push is treated as a standing one
	Sprint = {
		Animation = "SprintPush",
		Weight = 1,

		--@ The push outranks the sprint animation until BlendAt seconds into its track, then fades
		--@ out over BlendFade seconds so the run eases back in underneath it
		BlendAt = 1,
		BlendFade = 0.4,

		Status = "IsSprintPushing",
		Duration = 0.7,
		HitboxDelay = 0.25,
		Window = 1,
		MinSpeed = 14,

		Hitbox = {
			shape = "Box",
			size = Vector3.new(5, 5, 6),
			offset = Vector3.new(0, 0, -3.5),
			duration = 0.2,
			max_targets = 1,
			effect = "BluntHit",
		},

		--@ Timed to the shove, on top of the run the pusher keeps through the push
		Impulse = {
			delay = 0.25,
			speed = 12,
			duration = 0.6,
			falloff = 0.4,
			rampIn = 0.06,
			influence = 1,
			priority = 1,
		},

	},
}
