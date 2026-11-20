local SnakeVisuals = {}

local VisualsCore = require("../VisualsCore")

SnakeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Snake",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart", --@ The rig's own root; each asset's RootPart sits where that root stood when it was authored

	Prefix = "Strike", --@ Asset child name is Strike .. comboIndex

	ScaleWithCharacter = true,
	SyncPosition = true, --@ Welded through each asset's RootPart, so the effect rides the snake

	Lifetime = 3,
	FPS = 60,

	--@ Named keyframes in the authored clips, at 60fps: Snake Attack `snake attack`@0.167
	Frames = { 10 },
	AfterImage = {},

	--@ `Bite` and `Fall` were authored on the player's body; their RootPart sits where the snake's root stands in the paired layout
	OneShots = {
		Strike = { Asset = "Strike1", Frame = 10 },
		Lunge = { Asset = "Lunge", Frame = 9 }, --@ Snake Constrict Dash `Constrict Dash`@0.15
		Bite = { Asset = "Bite", Frame = 0 }, --@ Player Constrict Bit `bite`@0.283: the moment the scene starts
		Fall = { Asset = "Fall", Frame = 26 }, --@ Player Constrict Fall `fall`@0.433
	},
}

SnakeVisuals.DustSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Snake",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = false, --@ Dust stays where the body kicked it up
	Lifetime = 3,
	FPS = 60,

	--@ Slither Fast `Snake Fast`@0
	OneShots = {
		Fast = { Asset = "Fast", Frame = 0 },
	},
}

SnakeVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, SnakeVisuals.Settings)
end

SnakeVisuals.Strike = function(controller)
	VisualsCore.OneShot(controller, SnakeVisuals.Settings)
end

SnakeVisuals.Lunge = function(controller)
	VisualsCore.OneShot(controller, SnakeVisuals.Settings)
end

SnakeVisuals.Bite = function(controller)
	VisualsCore.OneShot(controller, SnakeVisuals.Settings)
end

SnakeVisuals.Fall = function(controller)
	VisualsCore.OneShot(controller, SnakeVisuals.Settings)
end

SnakeVisuals.Fast = function(controller)
	VisualsCore.OneShot(controller, SnakeVisuals.DustSettings)
end

return SnakeVisuals
