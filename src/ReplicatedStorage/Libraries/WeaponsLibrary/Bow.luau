return {
	Rig = "DrawstringBowRig",
	RigAttachments = { "ArrowReload" },
	idle_while_moving = true,
	idle_priority = "Action2",
	finisher = false,
	base_damage = 10,
	hit_stop = 0,
	hitbox = { effect = "ProjectileHitLimb" },

	projectile = {
		animations = {
			draw = "BowAim",
			hold = "BowAimIdle",
			fire = "BowFire",
			reload = "BowArrowEquip",
		},
		starts = { --@ Seconds into a clip it starts from
			fire = 5 / 60, --@ The string's snap; earlier frames only pull further after the arrow has already left
		},
		speeds = { --@ Clip playback per phase before the tier's `draw` multiplier
			draw = 1 / 3, --@ The 0.5 s draw stretched to 1.5 s, where `Weapons.Bow.Charge`'s creak peaks as the string reaches full; tiers pitch the sound up with the draw
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

		sounds = { --@ SoundLibrary paths, played from the archer (or where the arrow lands)
			draw = "Weapons.Bow.Charge",
			reload = "Weapons.Bow.Load",
			quick = "Weapons.Bow.QuickFire", --@ Loosed straight out of the draw
			charged = "Weapons.Bow.ChargedShot", --@ Loosed from a held, full draw
			impact = {
				path = "Weapons.Bow.Impact", --@ The struck surface's kind is added to this
				fallback = "Rock", --@ Kind for any material not listed
				materials = {
					[Enum.Material.Wood] = "Wood",
					[Enum.Material.WoodPlanks] = "Wood",
					[Enum.Material.Sand] = "Sand",
					[Enum.Material.Grass] = "Sand",
					[Enum.Material.LeafyGrass] = "Sand",
					[Enum.Material.Ground] = "Sand",
					[Enum.Material.Mud] = "Sand",
					[Enum.Material.Snow] = "Sand",
					[Enum.Material.Salt] = "Sand",
				},
			},
		},
		aim_fov = -8,
		aim_line = "Subtle",
		release_shake = "BowRelease",
		sever_carry = 0.35,
		unblockable = true, --@ Arrows land through a block and a counter
		
		arm_pitch = {
			joints = { "Right Shoulder", "Left Shoulder" },
			max = 60,
			rate = 14,
		},
	},
}
