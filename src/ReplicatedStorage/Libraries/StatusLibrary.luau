return{
	Types = {
		Default = {
			Priority = 0;
			IsStun = false;
		},

		Light = {
			WalkSpeed = 12,
		},

		IsSprinting = {
			WalkSpeed = 30,
			JumpPower = 50,
			Priority = 3;
			IsStun = false;
		};

		IsCrouching = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 1;
			IsStun = false;
		};

		SlowerMovement = {
			WalkSpeed = 5,
			JumpPower = 50,
			Priority = 0.2;
			IsStun = false;
		};
		
		NoWalk = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 5;
			IsStun = false;
		};

		NoMovement = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 5;
			IsStun = false;
		};

		Sprinting ={
			WalkSpeed = 30,
			JumpPower = 50,
			Priority = 1;
			IsStun = false;
		};

		IsBlocking = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		};

		IsStunned = {
			WalkSpeed = 5,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		IsStaggered = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		CanClash = {
			WalkSpeed = 4,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		Parrying = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		Dashing = {
			WalkSpeed = 5,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		Landed = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		IsAttacking = {
			WalkSpeed = 12,
			JumpPower = 0,
			Priority = 2;
			IsStun = true;
		},

		Blocking = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 1,
			IsStun = false
		},

		FullStun = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 4,
		},

		NoSprint = {
			WalkSpeed = 14,
			JumpPower = 0,
			Priority = 4,
		},

		NoJump = {
			--WalkSpeed = 0,
			JumpPower = 0,
			Priority = 4,
		},

		Knocked = {
			WalkSpeed = 0,
			JumpPower = 0,
			Priority = 777,
			IsStun = true
		},

		Emote = {
			WalkSpeed = 8,
			JumpPower = 0,
			Priority = 1,
			IsStun = false
		},

	},
}