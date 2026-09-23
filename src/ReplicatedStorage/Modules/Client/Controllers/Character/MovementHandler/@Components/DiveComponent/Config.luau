return {
	Speed = 60,
	Duration = 1,
	Cooldown = 1.5,

	--@ Outranks attack impulses, so a lunge landing mid-dash is ignored instead of stomping it
	ImpulsePriority = 2,

	--@ Starts at Floor of Speed and climbs exponentially to full speed on the direction's StartTime
	Ramp = {
		Floor = 0.15,
		Curve = 4,
	},

	Falloff = 0.8,
	CutoffSpeed = 10,
	ForcePerMass = 4e4,
	CleanupGrace = 0.5,

	Binds = { "W", "A", "S", "D", "Q" },
	BindAliases = { Q = "W" },

	Directions = {
		W = { Track = "DiveForward", StartTime = 0.125 },
		A = { Track = "DiveLeft", StartTime = 0.125 },
		S = { Track = "DiveBackward", StartTime = 0.2 },
		D = { Track = "DiveRight", StartTime = 0.125 },
	},

	TrackPriority = Enum.AnimationPriority.Action3,
	StopFade = 0.1,
	SwingReleaseFade = 0.1,

	--@ Share of Duration that IsDiving and DiveDirection stay applied
	StatusShare = 0.5,

	Visual = {
		Effect = "Movement.DodgeVisuals",
		Method = "Dodge",
	},
}
