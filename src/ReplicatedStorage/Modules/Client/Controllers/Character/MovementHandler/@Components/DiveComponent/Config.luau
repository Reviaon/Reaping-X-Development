return {
	Speed = 60,
	Duration = 1,
	Cooldown = 1.5,

	--@ Seconds of server-side hit immunity from activation; after it the dash can be hit and interrupted
	IFrames = 0.2,

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

	--@ The only directions a dive may take while blocking; the guard stays up through it
	BlockingDirections = { S = true },

	--@ A dive out of a sprint goes along the run and keeps the character facing it, whatever key is held
	SprintDirection = "W",
	--@ How fast a sprint dive turns toward a new run direction (exponential, per second); steering ends for good once the sprint does
	SprintTurnRate = 10,
	--@ Status source for the NoRotate a sprint dive holds so shift lock can't turn it toward the camera
	FacingSource = "Dive",

	--@ Share of the entry speed along the dive that the ramp starts from and the falloff settles on,
	--@ so a dive out of a run keeps its momentum and hands back at running speed. The falloff is then
	--@ shortened so the dive still covers only the standing dive's distance, plus SprintBonus studs
	--@ out of a sprint.
	Momentum = {
		Carry = 1,
		SprintBonus = 3,
		MinFalloff = 0.15,
	},

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
