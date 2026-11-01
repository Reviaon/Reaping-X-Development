return {
	BaseFov = 70,
	Height = 1.5,

	SettleDistance = 0.15,
	ReturnSpeed = 20,
	FovSpeed = 5,
	ReturnFovSpeed = 12,

	Punch = {
		Speed = 16,
		Damper = 0.6,

		Shapes = {
			Grab = { Roll = 3 },
			Push = { Fov = -4, Roll = 1.5 },
		},
	},

	Kick = {
		RiseSpeed = 14,
		SettleSpeed = 4,

		Shapes = {
			RunJump = { Fov = 8, Hold = 0.25 },
		},
	},

	Scene = {
		Blend = 0.5,
		FollowSpeed = 7,

		Fov = -10,

		EnterPunch = "Grab",

		Marker = "Hit",
		MarkerShake = "GrappleHit",
		MarkerSpacing = 0.05,
	},

	Scenes = {
		TackleGrapple = {},
		TackleGrappleBack = {},
		PushStruggle = {},
		PushGrab = {},
	},

	Sway = {
		Statuses = { "IsAttacking" },

		Share = 0.35,
		Depth = 0.15,
		MaxOffset = 0.8,

		Roll = 1.2,
		MaxRoll = 1.5,

		Speed = 18,
		Damper = 0.85,
	},
}
