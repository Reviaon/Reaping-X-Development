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
	}
}