return{
	Rig = nil,
	MaxCombo = 6,

	--@ Primary tuning knob: animation playback multiplier (1 = as authored). Every timing
	--@ in this file is written at 1x and divided by this at runtime - see
	--@ CombatHandler.Config:ResolveAttackTiming. Number, or a table keyed by combo index.
	attack_speed = 1,

	attack_cooldown = 0.5,
	attack_cooldown_final = 1,

	ease_out = 0.25, --@ How long to ease out the animation speed to 0 at the end of the attack
	ease_fade = 0.35, --@ How long to fade out the animation after the ease out has completed
	
	attack_duration = {
		0.63,
		0.56,
		0.76,
		0.583,
		0.583,
		0.833
	},

	light_impulse = {
		speed = 8,
		duration = 0.8,
		falloff = 0.5,
		priority = 1, --@ Higher priority impulses cannot be stomped by lower ones (see PhysicsService.ApplyImpulse)

		influence = 0.65, --@ Share of the player's walk speed that stays live during the push

		impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
			0.35,
			0.217,
			0.35,
			0.267,
			0.25,
			0.533
		}
	}
}