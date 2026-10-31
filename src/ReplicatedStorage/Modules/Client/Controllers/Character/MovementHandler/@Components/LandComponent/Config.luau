return {
	MaxAirtime = 5,

	HeavyAirtime = 3,
	MinJumpShare = 0.5,

	FadeTime = 0.1,

	FadeOut = 0.25,

	Walking = {Weight = 0.6, Hold = 0.2, Fade = 0.3},
	Sprinting = {Weight = 0.35, Hold = 0.25, Fade = 0.3},
	
	SprintStatus = "IsSprinting",
	SkipStatuses = {"IsRagdolled", "IsStunned", "IsDiving", "IsTackling"},

	Light = {
		Animation = "UniversalLightLand",
		Priority = Enum.AnimationPriority.Action2,
		Speed = 1,
	},

	Heavy = {
		Animation = "UniversalHeavyLand",
		Priority = Enum.AnimationPriority.Action2,
		Speed = 1,
		Status = "IsLanding",
		StatusFallback = 1,
		Shake = "HeavyLand", --@ ShakeLibrary shape played on touchdown
	},
}
