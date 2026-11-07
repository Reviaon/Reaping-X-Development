return {
	Projectile = {
		StateAttribute = "ProjectileState", --@ Set on an archer by RangedService from their aim state
		Phases = { Drawing = true, Holding = true }, --@ Aim states that count as aiming at a mob
		WindowGap = 0.5, --@ Seconds the aim may slip off its body before the read starts over
		CenterBand = 0.5, --@ Studs either side of the aim line where the hop side is a coin flip
		LogPrefix = "[Awareness]", --@ Debug-mode console tag for each read
	},
}
