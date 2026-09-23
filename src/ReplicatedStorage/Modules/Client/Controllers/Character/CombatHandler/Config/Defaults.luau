return {
	AttackDuration = 0.2,
	AttackCooldown = 0.3,
	ImpulseDelay = 0.2,

	ImpulseSpeed = 30,
	ImpulseDuration = 0.2,
	ImpulseFalloff = 0.2,
	RampIn = 0.06, --@ Seconds a lunge or shove takes to reach full speed; 0 is an instant step

	KnockbackFace = true, --@ Whether a hit turns the victim to face their attacker
	KnockbackFaceResponsiveness = 100,

	HitboxDuration = 0.1,
	HitboxSize = Vector3.new(6, 5, 7),
	HitboxOffset = Vector3.new(0, 0, -4),
	HitboxShapes = { Box = true, Sphere = true, Cylinder = true },

	EaseOut = 0.1,
	EasePause = 0.05,
	EaseFade = 0.15,

	MinAttackSpeed = 0.1,
	MaxAttackSpeed = 10,

	--@ The final hit of a combo launches and ragdolls its victim; a weapon's `finisher` overrides any key, `false` turns it off
	Finisher = {
		ragdoll = 1.5, --@ Seconds the victim stays ragdolled and stunned
		speed = 40, --@ Studs per second the victim is thrown away from the attacker
		lift = 32, --@ Studs per second of upward launch; 32 peaks about 2.6 studs up
		spin = 540, --@ Degrees per second the victim tumbles backward in the air; 0 flies rigid
		twist = 0.6, --@ Share of spin added again as random angular velocity, so the tumble yaws and rolls
		flail = 16, --@ Studs per second of random velocity given to each loose limb at launch
	},

	Visuals = {
		Suffix = "Visuals",
		Path = "Combat.Weapons.",
	},
}
