local FrogVisuals = {}

local VisualsCore = require("../VisualsCore")

FrogVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Frog",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart", --@ The rig's own root; each asset's RootPart sits where that root stood when it was authored

	Prefix = { "Whip", "Tongue" }, --@ Asset child name is one of these .. comboIndex

	ScaleWithCharacter = true,
	SyncPosition = true, --@ Welded through each asset's RootPart, so the effect rides the frog

	Lifetime = 3,
	FPS = 60,

	--@ Named keyframes in the authored clips, at 60fps: Frog Whip Attack `Hit`@0.933, Frog Tongue Attack `Tongue Attack`@0.783
	Frames = { 56, 47 },
	AfterImage = {},
	OneShots = {},
}

FrogVisuals.DashSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Frog/Dash",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = false, --@ Dust stays where the feet left the ground
	Lifetime = 3,
	FPS = 60,

	--@ Named keyframes in Frog Back Dash, at 60fps (`Jump`@0.333, `Land`@0.8); every dash clip uses them
	OneShots = {
		Dash = { { Asset = "Jump", Frame = 20 }, { Asset = "Land", Frame = 48 } },
	},
}

FrogVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, FrogVisuals.Settings)
end

FrogVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, FrogVisuals.Settings)
end

FrogVisuals.Dash = function(controller)
	VisualsCore.OneShot(controller, FrogVisuals.DashSettings)
end

return FrogVisuals
