return {
	Scope = "Projectile",
	Status = "IsAiming",
	Priority = Enum.AnimationPriority.Action3,
	CancelOn = { IsBlocking = true, IsRagdolled = true, IsDiving = true },
	NockWeld = "@NockWeld",

	Fades = {
		Draw = 0.1,
		Hold = 0.15,
		Fire = 0.05,
		Reload = 0.15,
		Stop = 0.25,
	},

	NextFade = {
		Drawing = "Hold",
		Firing = "Reload",
		Reloading = "Draw",
	},

	ClipKey = {
		Drawing = "draw",
		Firing = "fire",
		Reloading = "reload",
	},

	DefaultAnimations = {
		draw = "Aim",
		hold = "AimIdle",
		fire = "Fire",
		reload = "ArrowEquip",
	},

	FallbackLength = 0.5,
	FallbackRange = 400,
	FallbackOriginHeight = 1.5,
	MinShotDistance = 1,
	MaxCatchUp = 0.3,

	Facing = {
		Step = "ProjectileFacing",
		Priority = Enum.RenderPriority.Camera.Value + 3,
		MinDistance = 0.05,
	},

	FovKey = "ProjectileAim",

	Pitch = {
		ShoulderHeight = 0.5,
		DefaultMax = 60,
		DefaultRate = 14,
		Epsilon = 1e-3,
		SendInterval = 1 / 12,
		SendStep = 1.5,
	},
}
