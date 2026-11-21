local MockingJayVisuals = {}

local VisualsCore = require("../VisualsCore")

MockingJayVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/MockingJay",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart", --@ The rig's own root; each asset's RootPart sits where that root stood in `birdandbee`

	ScaleWithCharacter = true,
	SyncPosition = true, --@ Welded through each asset's RootPart, so the effect rides the bird
	CancelOn = {}, --@ The cry is armoured; hits don't clear it

	Lifetime = 3,
	FPS = 60,

	--@ Moon markers, at 60fps
	OneShots = {
		Cry = { { Asset = "CryStart", Frame = 0 }, { Asset = "Scream", Frame = 18 } }, --@ Jay Cry Start `1`@0, `2`@18
		Peck = { Asset = "Peck", Frame = 64 }, --@ Jay Ground Peck `peck`@64
		WingFlap = { Asset = "WingFlap", Frame = 65, Ground = 0 }, --@ Jay Fly Idle `wi`@65, on every loop of every flight clip; dropped to the floor under it, then welded so it travels with the bird
	},
}

MockingJayVisuals.CryLoopSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/MockingJay",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = true,
	CancelOn = {},
	ActiveAttribute = "IsCrying", --@ The cry clears it as its loop ends, which removes the loop's effects with it: their emitters run 2s, longer than the loop holds
	Lifetime = 3,
	FPS = 60,

	OneShots = {
		CryLoop = { Asset = "CryLoop", Frame = 0 }, --@ Every loop of Jay Cry Loop
		FlyCryLoop = { Asset = "FlyCryLoop", Frame = 0 }, --@ Every loop of Jay Fly Cry Loop, for a `cry.air` (the jay lands to cry instead)
	},
}

MockingJayVisuals.GroundSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/MockingJay",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = true,
	SyncPosition = false, --@ Dust stays where it was kicked up
	CancelOn = {},
	Lifetime = 3,
	FPS = 60,

	--@ Authored on the floor under the bird, so each is dropped onto the floor under it however high it flies
	OneShots = {
		Land = { Asset = "Land", Frame = 25, Ground = 0, Weld = false }, --@ Jay Land `land`@25
	},
}

MockingJayVisuals.CryShakeSettings = {
	Host = "RootPart",
	ActiveAttribute = "IsCrying", --@ Set on the bird from the cry's call until its loop ends; the shake lasts that long
	Shake = { --@ The wolf's screech, as Jae asked: the same shape, rhythm and widening
		Shape = "Screech", --@ ShakeLibrary shape knocked into the camera over and over while the cry lasts
		Interval = 0.07, --@ Seconds between knocks
		Fov = 14, --@ Degrees the field of view widens by while it lasts (CameraHandler eases it in and back out)
		Range = 90, --@ Studs from the bird past which both fade to nothing
	},
}

MockingJayVisuals.CryShake = function(controller)
	VisualsCore.Shake(controller, MockingJayVisuals.CryShakeSettings)
end

MockingJayVisuals.Attack = function() end --@ The peck's visual rides its clip (`clip_visuals.Peck`), so the attack timeline adds none

for _, name in { "Cry", "Peck", "WingFlap" } do
	MockingJayVisuals[name] = function(controller)
		VisualsCore.OneShot(controller, MockingJayVisuals.Settings)
	end
end

for _, name in { "CryLoop", "FlyCryLoop" } do
	MockingJayVisuals[name] = function(controller)
		VisualsCore.OneShot(controller, MockingJayVisuals.CryLoopSettings)
	end
end

for _, name in { "Land" } do
	MockingJayVisuals[name] = function(controller)
		VisualsCore.OneShot(controller, MockingJayVisuals.GroundSettings)
	end
end

return MockingJayVisuals
