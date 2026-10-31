return {
	Joint = "RootJoint",

	Forward = math.rad(12),
	Back = math.rad(12),
	Side = math.rad(12),

	FullSpeed = 24,
	FullAccel = 120,

	LeanRate = 7,
	AccelRate = 12,

	TeleportDistance = 20,
	RestEpsilon = math.rad(0.05),

	UprightStatuses = { "IsStunned", "IsRagdolled", "IsDiving" },
	UprightDuringImpulse = true,
}
