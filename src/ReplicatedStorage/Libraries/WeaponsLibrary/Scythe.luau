return{
	Rig = "ScytheRig",
	MaxCombo = 4,
	
	attack_speed = 1.2,

	attack_cooldown = 0.5,
	attack_cooldown_final = 1,

	ease_out = 0.1, --@ How long to ease out the animation speed to 0 at the end of the attack
	ease_fade = 0.25, --@ How long to fade out the animation after the ease out has completed
	
	attack_duration = {
		0.617,
		0.683,
		0.667,
		1.2,
	},

	light_impulse = {
		speed = 8,
		duration = 0.8,
		falloff = 0.5,
		priority = 1, --@ Higher priority impulses cannot be stomped by lower ones (see PhysicsService.ApplyImpulse)
		influence = 0.65, --@ Share of the player's walk speed that stays live during the push

		impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
			0.383,
			0.317,
			0.183,
			0.5
		}
	},

	--@ Attack hitbox. shape is Box, Sphere or Cylinder. size is one Vector3 whatever the shape:
	--@ Box uses all three axes, Cylinder takes radius from X and height from Y, Sphere takes
	--@ radius from X. offset is from the root, -Z forward. duration is how long the volume stays
	--@ live. Omit hitbox_delay and the cue rides impulse_delay above.
	hitbox = {
		shape = "Box",
		size = Vector3.new(9, 5, 7),
		offset = Vector3.new(0, 0, -4),
		duration = 0.1,
		max_targets = -1,
		effect = "BladeHit", --@ Impact particle under CombatVFX.Hit

		--@ The finisher is a spin, so it reads as a radius around the character rather than a
		--@ box in front of it. Shape may vary per combo; only size.X is used by Sphere.
		hitbox = {
			[4] = {
				shape = "Sphere",
				size = Vector3.new(9, 9, 9),
				offset = Vector3.new(0, 0, -1),
			},
		},
	},
}
