local WolfVisuals = {}

local VisualsCore = require("../VisualsCore")

WolfVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Wolf",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart", --@ The rig's own root; each asset's RootPart sits where that root stood when it was authored

	Prefix = { "Bite", "Slash" }, --@ Asset child name is one of these .. comboIndex

	ScaleWithCharacter = true, --@ Assets are authored around an unscaled wolf, so they shrink with the MobLibrary scale
	SyncPosition = true, --@ Welded through each asset's RootPart (its PrimaryPart), so the effect rides the wolf

	Lifetime = 3,
	FPS = 60,

	--@ Marker frames from the Moon Animator saves of M1s_M1 1-4 in wolf1.rbxl, at 60fps
	Frames = { 29, 28, 32, 24 },
	AfterImage = {},

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {},
}

WolfVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, WolfVisuals.Settings)
end

WolfVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.Settings)
end

return WolfVisuals
