return {
	--@ Seconds of airtime counted at most; anything longer lands as this much
	MaxAirtime = 5,

	--@ Seconds of airtime from which a landing is heavy. Anything under it is a light landing,
	--@ however short
	HeavyAirtime = 3,

	--@ Airtime under this share of the weakest jump the jump falloff still allows
	--@ (PropertiesHandler's Jump.MinPower) plays nothing, so a decayed jump that barely leaves the
	--@ ground, or a step off a kerb, has no landing
	MinJumpShare = 0.5,

	FadeTime = 0.1,

	--@ Seconds a landing takes to fade out at its end, so it eases back into what is under it
	FadeOut = 0.25,

	--@ Landing on the move: the landing plays at Weight so the walk or run shows through it, holds
	--@ for Hold seconds, then fades over Fade. A standing landing that starts moving fades the
	--@ same way. A landing that roots the character (Status) always plays whole
	Walking = { Weight = 0.6, Hold = 0.2, Fade = 0.3 },
	Sprinting = { Weight = 0.35, Hold = 0.25, Fade = 0.3 },
	SprintStatus = "IsSprinting",

	--@ Landing under any of these plays nothing
	SkipStatuses = { "IsRagdolled", "IsStunned", "IsDiving" },

	Light = {
		Animation = "UniversalLightLand",
		Priority = Enum.AnimationPriority.Action2,
		Speed = 1,
	},

	--@ Status is held for the animation's length, or StatusFallback seconds if the track has not
	--@ loaded its length yet. Set Status to nil for the animation alone
	Heavy = {
		Animation = "UniversalHeavyLand",
		Priority = Enum.AnimationPriority.Action2,
		Speed = 1,
		Status = "IsLanding",
		StatusFallback = 1,
	},
}
