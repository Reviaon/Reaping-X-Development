return {
	Template = { "Storage", "UIFolder", "StruggleUI" },

	Profiles = {
		Default = {
			TargetScore = 8,
			TimeLimit = 10,
			PointsPerHit = 1,
			PointsPerMiss = -1,
			CloseMargin = 0,

			Tolerance = 0.15,
			StartDelay = 1.2,

			ShrinkTime = 1.4,
			StartScale = 0.85,
			InnerScale = 0.55,
			HitLeeway = 0.12,
			EndScale = 0.3,

			Waves = {
				{ Count = 1, Weight = 8 },
				{ Count = 2, Weight = 1 },
			},

			WaveSpacing = 0.9,

			Keys = { "Q", "E", "R", "F", "Z", "X" },
			Area = { Min = Vector2.new(0.28, 0.32), Max = Vector2.new(0.72, 0.78) },

			MinSpacing = 0.25,
			PlacementTries = 12,

			Npc = {
				Accuracy = 0.5,
				Reaction = NumberRange.new(0.05, 0.3),
			},

			Style = {
				Accent = Color3.fromRGB(32, 170, 85),
				Miss = Color3.fromRGB(212, 70, 70),
				Expire = Color3.fromRGB(104, 104, 112),

				ReadyThickness = 2.5,
				ApproachFade = NumberRange.new(0.1, 0.8),
				SheenSpeed = 70,

				SpawnScale = 0.6,
				AppearSpeed = 24,
				AppearDamping = 0.65,
				ColourSpeed = 28,
				BurstScale = 1.22,

				MissJitter = 7,
				MissJitterSpeed = 45,
				MissJitterDamping = 0.25,
				MissHold = 0.22,

				FadeTime = 0.22,
			},
		},
	},
}
