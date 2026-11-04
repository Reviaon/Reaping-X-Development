return {
	Rig = "IronBowRig",
	RigAttachments = { "ArrowReload" },
	idle_while_moving = true,
	idle_priority = "Action2",
	finisher = false,
	base_damage = 10,
	hitbox = { effect = "ProjectileHitLimb" },

	projectile = {
		animations = {
			draw = "BowAim",
			hold = "BowAimIdle",
			fire = "BowFire",
			reload = "BowArrowEquip",
		},
		nock = {
			part = "Arrow",
			idle = "ArrowIdle",
			aim = "ArrowAim",
			reload = "ArrowReload",
			reappear_at = 0.5,
		},

		release_at = 0,
		model = "Arrow",
		trail = "ArrowTrail",
		
		speed = 250,
		gravity = 0.35,
		max_range = 400,
		fire_interval = 1.6,

		tiers = {
			Wooden = { draw = 1, speed = 260, gravity = 0.32 },
			Stone = { draw = 1.2, speed = 280, gravity = 0.28 },
			Diamond = { draw = 1.4, speed = 300, gravity = 0.24 },
		},

		obstacle_effect = "ProjectileHitObstacle",
		aim_fov = -8,
		release_shake = "BowRelease",
		sever_carry = 0.35,
		
		arm_pitch = {
			joints = { "Right Shoulder", "Left Shoulder" },
			max = 60,
			rate = 14,
		},
	},
}
