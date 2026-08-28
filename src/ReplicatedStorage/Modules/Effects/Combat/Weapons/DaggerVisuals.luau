local DaggerVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

DaggerVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Dagger",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex
	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Dagger
	Frames = { 23, 27, 16, 25, 27 },
	AfterImage = {},
}

--@ Handles Combat Visuals For Dagger
DaggerVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, DaggerVisuals.Settings)
end

return DaggerVisuals
