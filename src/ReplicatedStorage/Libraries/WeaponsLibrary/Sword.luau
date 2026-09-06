return{
	Rig = "SwordRig",
	MaxCombo = 4,

	attack_cooldown = .5,
	attack_cooldown_final = 2,

	attack_duration = {
		0.733,
		0.850,
		0.750,
		2
	},

	light_impulse = {
		priority = 1, --@ Per-combo entries below may override this individually
		influence = 0.65, --@ Inherited by the per-combo entries below unless they set their own
		impulse = {
			{ speed = 8, duration = 0.8, falloff = 0.5 },
			{ speed = 8, duration = 0.8, falloff = 0.5 },
			{ speed = 8, duration = 0.8, falloff = 0.5 },
			{ speed = 8, duration = 2, falloff = 1.5 },
		},
		impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
			0.45,
			0.550,
			0.383,
			0.25
		}
	},

	--@ Attack hitbox. shape is Box, Sphere or Cylinder. size is one Vector3 whatever the shape:
	--@ Box uses all three axes, Cylinder takes radius from X and height from Y, Sphere takes
	--@ radius from X. offset is from the root, -Z forward. duration is how long the volume stays
	--@ live. Omit hitbox_delay and the cue rides impulse_delay above.
	hitbox = {
		shape = "Box",
		size = Vector3.new(6, 5, 7),
		offset = Vector3.new(0, 0, -4),
		duration = 0.1,
		max_targets = -1,
		effect = "BladeHit", --@ Impact particle under CombatVFX.Hit

		--@ Per-combo overrides, indexed like impulse_delay. The finisher swings wider.
		hitbox = {
			[4] = {
				size = Vector3.new(9, 6, 9),
				offset = Vector3.new(0, 0, -4.5),
			},
		},
	},
}
