return {
	AnimationFolder = { "Storage", "Animations", "Mobs" }, --@ Under ReplicatedStorage; each mob's clips sit in a folder named after it
	LiveFolder = { "World", "Live" }, --@ Under Workspace; bites look for victims here

	ShotKeys = { --@ Number row in hotbar order; a morph's ability tools take the first slots and its shots the rest
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine,
		Enum.KeyCode.Zero,
	},

	DisabledStates = { --@ Humanoid states a morph never enters; set on this client, which owns its physics
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.PlatformStanding,
		Enum.HumanoidStateType.Flying,
		Enum.HumanoidStateType.StrafingNoPhysics,
		Enum.HumanoidStateType.GettingUp,
	},

	YieldStatuses = { IsRagdolled = true }, --@ Statuses that, besides hit-yields and action locks, cut an action short and block new ones, as they do a player's attacks
	OwnStatuses = { ShiftLock = true, IsSprinting = true, IsAttacking = true }, --@ Statuses the morph's own walk, run and bite stand in for; every other status scales its speed and jump as it would a player's

	IdleThreshold = 0.75, --@ Studs/s below which locomotion idles
	RunHysteresis = 2, --@ Studs/s around the walk/run midpoint before the clip switches
	PlaybackRange = { 0.6, 1.4 }, --@ Locomotion playback clamp against the mob's own walk and run speeds
	PlaybackEpsilon = 0.05,
	LocomotionFade = 0.25,
	ExclusiveFade = 0.15, --@ Seconds an animation_exclusive partner fades out before the other starts
	ActionFade = 0.1,
	MissFade = 0.05, --@ Seconds an ability clip fades into its miss clip, as the mob's does
	DeathFade = 0.3,
	HoldFallback = 3, --@ Seconds a whole-clip hold lasts when the clip length isn't loaded yet

	BurstName = "MorphBurst", --@ Name of the LinearVelocity that drives dashes
	BurstForcePerMass = 2000, --@ Planar force per unit of assembly mass behind a burst

	LeapCone = 40, --@ Degrees off the morph's facing a leap looks for a target within its range; with none it leaps straight ahead at the leap's top speed, both capped by the entry's leap_distance
	LeapArrival = 0.8, --@ Share of the airtime a locked-on leap reaches its landing in, so the server sees it arrive before the bite lands
	LungeFacing = "MorphLunge", --@ NoRotate source held while a bite lunge or leap turns the morph to face where it is going
	LungeDepth = 0.7, --@ Share of a bite's reach it stops short of a tracked target, as the mob's step-in does
	CoastEase = 2, --@ How a leap's overrun (the mob's leap.overrun) eases to a stop past the landing

	DashDistance = 14, --@ Used when a morph's dash leaves distance out
	DashCooldown = 0.5, --@ Used when a morph's dash leaves cooldown out
}
