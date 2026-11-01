return {
	Animations = { "Storage", "Animations" },
	Assets = { "Storage", "Particles", "SceneVFX" },
	Parent = { "World", "Visuals" },
	LivePath = { "World", "Live" },
	AnchorAttribute = "PairSceneAnchor",

	Lifetime = 4,
	MinWeight = 0.1,

	TorsoParts = { "UpperTorso", "Torso" },

	FullJump = {
		MinRise = 45,
		Window = 0.2,
	},

	Airborne = {
		GroundDistance = 3.4,
		MinTime = 0.15,
		MaxTime = 3,
		Fade = 0.3,
		Linger = 1,
	},

	Visuals = {
		TackleMiss = {
			{ At = 0.08, Effect = "DiveMiss1" },
			{ At = 0.62, Effect = "DiveMiss2" },
		},

		Push = {
			{ At = 0.18, Effect = "StandingPush" },
		},

		UniversalSprintJump = {
			{ At = 0, Kick = "RunJump", FullJump = true },
			{ At = 0.12, Effect = "RunJump", Anchor = "Start", FullJump = true },
			{ At = 0, Effect = "StumbleRunJump", Follow = true, Airborne = true, FullJump = true },
		},

		UniversalHitReaction1 = {
			{ At = 0.05, Effect = "hit1", Attach = true },
		},

		UniversalHitReaction2 = {
			{ At = 0.07, Effect = "hit2", Attach = true },
		},

		UniversalHitReaction3 = {
			{ At = 0.05, Effect = "hit3", Attach = true },
		},

		TackleHitVictim = {
			{ At = 0.33, Effect = "DiveIntoGrappleFall" },
		},

		TackleVictimBack = {
			{ At = 0.37, Effect = "DiveIntoGrappleBackFall" },
		},

		TackleHitAttackerLoop = {
			{ Marker = "Hit", Effect = "grappleloophit", Anchor = "Partner" },
		},

		TackleHitVictimBackLoop = {
			{ At = { 0.3, 0.917, 2.13, 2.7, 4.8 }, Effect = "BackGrappleVariantHit" },
		},

		GrabFailAttacker = {
			{ Marker = "Hit", Effect = "headlockgrabescapehit" },
			{ Marker = "Ragdoll", Effect = "headlockgrabescapehit2", Anchor = "Partner" },
		},

		GrabFailVictim = {
			{ Marker = "Ragdoll", Effect = "headlockbreakneckdrop" },
		},
	},
}
