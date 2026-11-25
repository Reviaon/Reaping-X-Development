return {
	Animations = { "Storage", "Animations" },
	Assets = { "Storage", "Particles", "SceneVFX" },
	Parent = { "World", "Visuals" },
	LivePath = { "World", "Live" },
	AnchorAttribute = "PairSceneAnchor",

	Lifetime = 4,
	MinWeight = 0.1,
	HoldFade = 0.2, --@ Seconds a Hold sound fades out over when its clip stops

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
			{ At = 1.45, Effect = "grappleloophit", Mount = "Block", On = "Right Arm" },
		},

		TackleHitVictimBackLoop = {
			{ At = { 0.3, 0.917, 2.13, 2.7, 4.8 }, Effect = "BackGrappleVariantHit" },
		},

		GrabFailAttacker = {
			{ Marker = "Hit", Effect = "headlockgrabescapehit" },
			{ Marker = "Ragdoll", Effect = "headlockgrabescapehit2", Anchor = "Partner" },
		},

		GrabFailVictim = {
			{ At = 0.55, Effect = "headlockbreakneckdrop", Mount = "crack" },
			{ At = 1.1, Effect = "headlockbreakneckdrop" },
		},
	},

	Sounds = { --@ Clip -> SoundLibrary paths cued on it: At (seconds, or a list) or Marker as in Visuals; Hold plays from the clip's start until it stops; Anchor = "Partner" plays from the scene partner
		TackleMiss = {
			{ Marker = "DiveMiss", Sound = "Abilities.Tackle.Miss" },
		},

		TackleHitAttackerLoop = {
			{ Marker = "Hit", Sound = "Abilities.Tackle.FacePunch", Anchor = "Partner" }, --@ The victim's face, on each punch
		},

		TackleHitVictimBackLoop = {
			{ At = { 0.3, 0.917, 2.13, 2.7, 4.8 }, Sound = "Abilities.Tackle.FaceSlam" }, --@ Same beats as BackGrappleVariantHit
		},

		Push = {
			{ At = 0.18, Sound = "Abilities.Push.Whiff" },
		},

		SprintPush = {
			{ At = 0.25, Sound = "Abilities.Push.Whiff" }, --@ PushLibrary.Sprint.HitboxDelay
		},

		GrabStartVictim = {
			{ At = 0.17, Sound = "Abilities.Grab.Hit" }, --@ Where the victim's head first jerks in the clip
		},

		GrabStruggleVictimLoop = {
			{ Hold = true, Sound = "Abilities.Grab.Loop" },
		},

		GrabFailAttacker = {
			{ Marker = "Hit", Sound = "Abilities.Grab.Fail" }, --@ The victim breaks free
		},

		GrabFailVictim = {
			{ At = 0.55, Sound = "Abilities.Grab.NeckDamaged" }, --@ The neck crack
		},
	},
}
