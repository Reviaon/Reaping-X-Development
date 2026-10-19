return {
	Scope = "Properties",

	BaseWalkSpeed = 10,
	BaseJumpPower = 50,

	Jump = {
		DecayStep = 10, --@ JumpPower lost per jump
		MinPower = 25, --@ Below this, jumping is off until the reset
		ResetCooldown = 0.5, --@ Seconds a fully decayed jump stays off
		IdleReset = 2, --@ Seconds without jumping that restore full JumpPower
	},
}
