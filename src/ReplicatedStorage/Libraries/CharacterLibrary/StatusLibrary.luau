return{
	DefaultChecks = { "IsStunned", "IsSprinting", "IsDiving"},
	PropertyModes = { JumpPower = "Min" },
	
	Types = {
		Default = {
			WalkSpeed = 12,
			JumpPower = 50,
			AutoRotate = true,
			Priority = 0
		},
		
		IsStunned = {
			WalkSpeed = 6,
			JumpPower = 0,
			Priority = 10;
		};

		IsRagdolled = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 11;
		};

		IsSprinting = {
			WalkSpeed = 30,
			JumpPower = 50,
			Priority = 3;
		};	

		IsAttacking = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 4;
		};

		IsDiving = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 4;
		};

		IsBlocking = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 3;
		};

		IsCrouching = {
			WalkSpeed = 5,
			JumpPower = 0,
			Priority = 1;
		};

		ShiftLock = {
			WalkSpeed = 10,
			JumpPower = 50,
			Priority = 1,
		},

		NoJump = {
			JumpPower = 0,
			Priority = 3;
		},

		Emote = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 1,
		},
	},
}