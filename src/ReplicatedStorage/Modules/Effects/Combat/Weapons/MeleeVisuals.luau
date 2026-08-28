local MeleeVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

MeleeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Melee",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Melee
	Frames = { 21, 13, 21, 16, 15, 32 },
	AfterImage = {},
}

--@ Handles Combat Visuals For Melee
MeleeVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, MeleeVisuals.Settings)
end

return MeleeVisuals
