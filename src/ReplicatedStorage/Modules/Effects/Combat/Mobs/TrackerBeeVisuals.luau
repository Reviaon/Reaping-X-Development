local TrackerBeeVisuals = {}

local VisualsCore = require("../VisualsCore")

TrackerBeeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/TrackerBee",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart", --@ The rig's own root; each asset's RootPart sits where that root stood in `birdandbee`

	Prefix = "Dash", --@ Asset child name is Dash .. comboIndex

	ScaleWithCharacter = false, --@ The kits were authored round the rig at its 1.83 scale already
	SyncPosition = true, --@ Welded through each asset's RootPart, so the effect rides the bee

	Lifetime = 3,
	FPS = 60,

	--@ Moon markers, at 60fps: BeeStartupDashAttack `Hit1`@56, the stinger charge @27
	Frames = { 56 },
	AfterImage = {},

	OneShots = {
		[1] = { Asset = "Charge", Frame = 27 },
		Latch = { Asset = "Latch", Frame = 69 }, --@ Bee Startup Latch `hit1`@69
		Rage = { Asset = "Rage", Frame = 0 }, --@ Bee Rage Aggro @0: the head and torso rage
		Fly = { Asset = "Fly", Frame = 0 }, --@ Bee Fast Flying @0, every loop
	},
}

TrackerBeeVisuals.HoverSettings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Mobs/TrackerBee",
	Parent = "Workspace/World/Visuals",
	Host = "RootPart",
	ScaleWithCharacter = false,
	SyncPosition = false, --@ The dust stays where the wings blew it up
	Lifetime = 3,
	FPS = 60,

	--@ Bee Idle @0, every loop: the ground smoke under the hover
	OneShots = {
		Hover = { Asset = "Hover", Frame = 0 },
	},
}

TrackerBeeVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, TrackerBeeVisuals.Settings)
end

TrackerBeeVisuals.Latch = function(controller)
	VisualsCore.OneShot(controller, TrackerBeeVisuals.Settings)
end

TrackerBeeVisuals.Rage = function(controller)
	VisualsCore.OneShot(controller, TrackerBeeVisuals.Settings)
end

TrackerBeeVisuals.Fly = function(controller)
	VisualsCore.OneShot(controller, TrackerBeeVisuals.Settings)
end

TrackerBeeVisuals.Hover = function(controller)
	VisualsCore.OneShot(controller, TrackerBeeVisuals.HoverSettings)
end

return TrackerBeeVisuals
