return {
	Defaults = {
		Speed = 180,
		Gravity = 0.35,
		Range = 400,
	},

	Stick = {
		Time = 10,
		Depth = 0.8,
	},

	PoolSize = 12,
	TipRotation = CFrame.Angles(0, math.rad(90), 0),

	PassThrough = { HumanoidRootPart = true },
	MaxPasses = 4,

	Dodge = {
		From = "ProjectileDodgeFrom",
		Until = "ProjectileDodgeUntil",
	},

	Debug = {
		Lifetime = 5,
		Color = Color3.fromRGB(255, 170, 0),
		HitColor = Color3.fromRGB(255, 60, 60),
	},
}
