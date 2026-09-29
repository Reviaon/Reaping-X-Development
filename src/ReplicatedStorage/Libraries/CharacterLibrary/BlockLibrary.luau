return {
	--@ MaxHealth / HitCost is how many hits a guard absorbs before it drops.
	MaxHealth = 100,
	HitCost = 20,

	--@ Seconds after the last blocked hit before block health refills, and how much per second.
	RegenDelay = 2,
	RegenRate = 25,

	--@ Seconds a broken guard can't be raised. Block health is back to MaxHealth when it ends.
	BreakLockout = 2,

	--@ Seconds after lowering a guard that absorbed a hit in which a swing takes priority over
	--@ whoever threw that hit: their hits are refused until the swing ends.
	CounterWindow = 0.5,

	HealthAttribute = "BlockHealth",
	MaxHealthAttribute = "MaxBlockHealth",
	GuardStatus = "IsGuarding",
	BrokenStatus = "GuardBroken",

	--@ ClientEffects path held on a broken guard's head for the lockout.
	DazeEffect = "Combat.Daze",

	--@ {Weapon}BlockIdle and {Weapon}BlockReaction1..n under Storage.Animations. A weapon with no
	--@ idle of its own holds UniversalIdle; one with no reactions plays none.
	Animations = {
		UniversalIdle = "UniversalBlock",
		IdleSuffix = "BlockIdle",
		ReactionSuffix = "BlockReaction",
		IdlePriority = Enum.AnimationPriority.Action2,
		ReactionPriority = Enum.AnimationPriority.Action3,
		IdleFade = 0.15,
		ReactionFade = 0.05,
	},
}
