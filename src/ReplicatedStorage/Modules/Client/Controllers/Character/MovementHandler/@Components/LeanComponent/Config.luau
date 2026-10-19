return {
	--@ Motor6D under the HumanoidRootPart the lean is written to
	Joint = "RootJoint",

	--@ Radians at full lean: pitched forward, pitched back, banked to either side
	Forward = math.rad(12),
	Back = math.rad(12),
	Side = math.rad(12),

	--@ Studs per second that give the full directional lean; a walk gets its share of it
	FullSpeed = 24,

	--@ Studs per second per second that give the full lean from a change of speed. This is what banks
	--@ the body into a turn and pitches it back on a stop. Lower leans harder
	FullAccel = 120,

	--@ How quickly the lean follows, and how hard the measured acceleration is smoothed
	LeanRate = 7,
	AccelRate = 12,

	--@ Studs in one frame treated as a teleport rather than movement
	TeleportDistance = 20,

	--@ Radians under which the joint is put back on its rest pose and left alone
	RestEpsilon = math.rad(0.05),

	--@ Statuses that hold the body upright
	UprightStatuses = { "IsStunned", "IsRagdolled", "IsDiving" },

	--@ Upright while a lunge, dive or knockback mover is driving the root
	UprightDuringImpulse = true,
}
