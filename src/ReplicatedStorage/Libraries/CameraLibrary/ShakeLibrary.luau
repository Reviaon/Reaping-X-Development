return {
	Enabled = true,

	--@ The grain of every shake: each axis is knocked by a whole number of steps between -Steps and Steps
	Steps = 10,

	--@ Amplifier is the studs one step is worth, Damper the rattle (lower settles slower and rings more).
	--@ Played by name through CameraHandler:Shake, so every shake in the game goes through the one
	--@ handler that owns the camera
	Shapes = {
		HitDealt = { Amplifier = 0.02, Damper = 0.6 },
		HitTaken = { Amplifier = 0.04, Damper = 0.6 },
		Blocked = { Amplifier = 0.025, Damper = 0.6 },
		GuardBroken = { Amplifier = 0.06, Damper = 0.75 },
		HeavyLand = { Amplifier = 0.07, Damper = 0.78 },
	},
}
