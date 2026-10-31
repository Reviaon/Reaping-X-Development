return {
	Speed = 75,
	Duration = 1,
	Cooldown = 1.5,

	IFrames = 0.2,
	ImpulsePriority = 2,

	Ramp = {
		Floor = 0.5,
		Curve = 4,
	},

	Falloff = 0.6,
	CutoffSpeed = 10,
	ForcePerMass = 4e4,
	CleanupGrace = 0.5,

	Binds = { "W", "A", "S", "D", "Q" },
	BindAliases = { Q = "W" },

	BlockingDirections = { S = true, W = true, A = true, D = true },

	SprintDirection = "W",
	SprintTurnRate = 10,
	FacingSource = "Dive",

	Momentum = {
		Carry = 1,
		SprintBonus = 3,
		MinFalloff = 0.15,
	},

	Directions = {
		W = { Track = "DiveForward", StartTime = 0.06 },
		A = { Track = "DiveLeft", StartTime = 0.06 },
		S = { Track = "DiveBackward", StartTime = 0.1 },
		D = { Track = "DiveRight", StartTime = 0.06 },
	},

	TrackPriority = Enum.AnimationPriority.Action3,
	TrackSpeed = 1.3,
	StopFade = 0.1,

	SwingReleaseFade = 0.1,
	StatusShare = 0.5,

	Visual = {
		Effect = "Movement.DodgeVisuals",
		Method = "Dodge",

		SustainSpeed = 0.4,
	},
}
