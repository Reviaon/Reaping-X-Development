return{
	DefaultChecks = { "IsStunned", "IsSprinting", "IsDiving"},
	HitImmune = { "IsRagdolled", "IsRecovering", "IFrames", "InPairScene" },
	HitYield = { "IsStunned", "GuardBroken", "IsGrappled" },
	HitGuard = { "IsGuarding" },
	ActionLock = { "IsPushing", "IsSprintPushing", "IsTackling", "InPairScene" },
	PropertyModes = { JumpPower = "Min" },
	
	Types = {
		Default = {
			WalkSpeed = 12,
			JumpPower = 50,
			AutoRotate = true,
			Priority = 0
		},
		
		IsStunned = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 10;
		};

		IsRagdolled = {
			WalkSpeed = 0,
			JumpPower = 0,
			AutoRotate = false,
			Priority = 11;
		};

		IsRecovering = {
			Priority = 2;
		};

		IFrames = {
			Priority = 2;
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

		IsAiming = {
			WalkSpeed = 8,
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

		IsGuarding = {
			Priority = 3;
		};

		GuardBroken = {
			WalkSpeed = 4,
			JumpPower = 0,
			Priority = 2;
		};

		ComboLocked = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 5;
		};

		IsPushing = {
			WalkSpeed = 4,
			JumpPower = 0,
			Priority = 6;
		};

		IsSprintPushing = {
			WalkSpeed = 18,
			JumpPower = 0,
			Priority = 6;
		};

		IsTackling = {
			WalkSpeed = 0,
			JumpPower = 0,
			AutoRotate = false,
			Priority = 7;
		};

		IsRunJumping = {
			Priority = 0;
		};

		InPairScene = {
			WalkSpeed = 0,
			JumpPower = 0,
			AutoRotate = false,
			Priority = 9;
		};

		IsGrappling = {
			Priority = 9;
		};

		IsGrappled = {
			Priority = 9;
		};

		IsLanding = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 5;
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