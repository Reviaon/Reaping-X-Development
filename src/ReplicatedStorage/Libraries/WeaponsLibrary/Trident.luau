return{
	Rig = "TridentRig",
	MaxCombo = 3,
	
	attack_speed = 1.2,

	attack_cooldown = 0.5,
	attack_cooldown_final = 1,

	ease_out = 0.1, --@ How long to ease out the animation speed to 0 at the end of the attack
	ease_fade = 0.25, --@ How long to fade out the animation after the ease out has completed
	
	attack_duration = {
		0.650,
		0.833,
		1.3,
	},

	light_impulse = {
		speed = 8,
		duration = 0.8,
		falloff = 0.5,
		priority = 1, --@ Higher priority impulses cannot be stomped by lower ones (see PhysicsService.ApplyImpulse)
		influence = 0.65, --@ Share of the player's walk speed that stays live during the push

		impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
			0.417,
			0.450,
			0.417,
		}
	},

	--@ Attack hitbox. shape is Box, Sphere or Cylinder. size is one Vector3 whatever the shape:
	--@ Box uses all three axes, Cylinder takes radius from X and height from Y, Sphere takes
	--@ radius from X. offset is from the root, -Z forward. duration is how long the volume stays
	--@ live. Omit hitbox_delay and the cue rides impulse_delay above.
	hitbox = {
		shape = "Box",
		size = Vector3.new(6, 5, 9.5),
		offset = Vector3.new(0, 0, -5),
		duration = 0.1,
		max_targets = -1,
		effect = "BladeHit", --@ Impact particle under CombatVFX.Hit
	},
}
