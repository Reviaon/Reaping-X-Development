return {
	--@ Share of workspace gravity a jump started from a sprint feels, while rising and while falling
	RiseGravity = 0.6,
	FallGravity = 0.6,

	--@ Seconds after takeoff the lighter gravity lasts at most, so a run off a ledge still falls normally
	MaxAirtime = 0.8,

	--@ Statuses that drop the lighter gravity at once
	CancelOn = { "IsStunned", "IsRagdolled", "IsDiving" },

	ForceName = "@run_jump_lift",
}
