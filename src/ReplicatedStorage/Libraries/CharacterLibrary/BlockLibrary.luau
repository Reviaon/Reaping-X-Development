return {
	MaxHealth = 100,
	HitCost = 20,

	RegenDelay = 2,
	RegenRate = 25,
	BreakLockout = 2,

	CounterWindow = 0.5,

	Arc = 180,
	RetryDelay = 0.25,

	ComboLockout = 0.3,
	LockStatus = "ComboLocked",

	HealthAttribute = "BlockHealth",
	MaxHealthAttribute = "MaxBlockHealth",
	GuardStatus = "IsGuarding",
	BrokenStatus = "GuardBroken",

	Shakes = {
		Absorbed = "Blocked",
		Broken = "GuardBroken",
	},

	DazeEffect = "Combat.Daze",

	Animations = {
		UniversalIdle = "UniversalBlock",
		IdleSuffix = "BlockIdle",
		ReactionSuffix = "BlockReaction",

		IdlePriority = Enum.AnimationPriority.Action2,
		ReactionPriority = Enum.AnimationPriority.Action3,

		IdleFade = 0.15,
		ReactionFade = 0.05,

		Break = "UniversalGaurdBreak",
		BreakPriority = Enum.AnimationPriority.Action4,
		BreakFade = 0.1,
	},
}
