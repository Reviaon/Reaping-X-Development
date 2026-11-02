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

WolfVisuals.MaulSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Wolf/Maul",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = true,
	Lifetime = 3,
	FPS = 60,

	--@ Marker frames from the "Beat down (5)_Clawin" Moon Animator save in wolf2.rbxl (ClawingBitingCombo), at 60fps
	OneShots = {
		Maul = {
			{ Asset = "Bite1", Frame = 12 },
			{ Asset = "Slash2", Frame = 94 },
			{ Asset = "Bite3", Frame = 137 },
			{ Asset = "Bite4", Frame = 184 },
		},
	},
}

WolfVisuals.EatSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Wolf/Eat",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ActiveAttribute = "IsFeeding", --@ Set on the wolf while its eating loop plays; the moment it clears, this loop's visuals stop
	ScaleWithCharacter = true,
	SyncPosition = true,
	Lifetime = 3,
	FPS = 60,

	--@ Marker frames from the "Beat down (6)_Eating" Moon Animator save in wolf2.rbxl (EatingLoop), at 60fps; played every loop
	OneShots = {
		Eat = {
			{ Asset = "Eat Bite", Frame = 8 },
			{ Asset = "bitehold", Frame = 12 },
			{ Asset = "Eat Bite1.5", Frame = 112 },
			{ Asset = "Eat Bite2", Frame = 139 },
		},
	},
}

WolfVisuals.ScreechSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Wolf/Screech",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	CancelOn = {}, --@ The screech plays through hits, so its visual does too
	ScaleWithCharacter = true,
	SyncPosition = true,
	Lifetime = 4,
	FPS = 60,

	--@ Marker frame from the M1s_Screech Moon Animator save in wolf2.rbxl, at 60fps
	OneShots = {
		Screech = { { Asset = "Screech", Frame = 132 } },
	},
}

WolfVisuals.ScreechShakeSettings = {
	Host = "RootPart",
	ActiveAttribute = "IsScreeching", --@ Set on the wolf from the screech's Begin marker to its End marker; the shake lasts that long
	Shake = {
		Shape = "Screech", --@ ShakeLibrary shape knocked into the camera over and over while the screech lasts
		Interval = 0.07, --@ Seconds between knocks
		Fov = 14, --@ Degrees the field of view widens by while it lasts (CameraHandler eases it in and back out)
		Range = 90, --@ Studs from the wolf past which both fade to nothing
	},
}

WolfVisuals.DashSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/Wolf/Dash",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = false, --@ Dust stays where the feet left the ground
	Lifetime = 3,
	FPS = 60,

	--@ Marker frames from the M1s_DashB Moon Animator save in wolf1.rbxl, at 60fps; every dash clip uses them
	OneShots = {
		Dash = { { Asset = "Dash", Frame = 10 }, { Asset = "Dash", Frame = 36 } },
	},
}

WolfVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, WolfVisuals.Settings)
end

WolfVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.Settings)
end

WolfVisuals.Maul = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.MaulSettings)
end

WolfVisuals.Eat = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.EatSettings)
end

WolfVisuals.Screech = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.ScreechSettings)
end

WolfVisuals.ScreechShake = function(controller)
	VisualsCore.Shake(controller, WolfVisuals.ScreechShakeSettings)
end

WolfVisuals.Dash = function(controller)
	VisualsCore.OneShot(controller, WolfVisuals.DashSettings)
end

return WolfVisuals
