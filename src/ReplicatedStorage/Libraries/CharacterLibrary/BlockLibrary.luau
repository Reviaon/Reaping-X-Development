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

	--@ Degrees in front of the blocker the guard covers, centred on where they face. A hit thrown
	--@ from outside it lands as if there were no guard.
	Arc = 180,

	--@ Seconds a held block waits before asking again after the server refuses a raise.
	RetryDelay = 0.25,

	--@ A hit that lands keeps the guard down for its hitstun plus this many seconds, so a held block
	--@ can't come up in the gap between two hits of a combo (Hitstun.Settings.Escape). Longer than
	--@ that gap, with room for a swing that arrives late
	ComboLockout = 0.3,
	LockStatus = "GuardLocked",

	HealthAttribute = "BlockHealth",
	MaxHealthAttribute = "MaxBlockHealth",
	GuardStatus = "IsGuarding",
	BrokenStatus = "GuardBroken",

	--@ ShakeLibrary shape the blocker's own screen takes for each Guard event.
	Shakes = {
		Absorbed = "Blocked",
		Broken = "GuardBroken",
	},

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

		--@ Played on a broken guard in place of the last reaction, sped or slowed so it ends with
		--@ the lockout.
		Break = "UniversalGaurdBreak",
		BreakPriority = Enum.AnimationPriority.Action4,
		BreakFade = 0.1,
	},
}
