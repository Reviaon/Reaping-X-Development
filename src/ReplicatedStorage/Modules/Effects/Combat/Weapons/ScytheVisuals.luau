local ScytheVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

ScytheVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Scythe",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Scythe
	Frames = { 23, 19, 11, 30 },
	AfterImage = {},
}

--@ Handles Combat Visuals For Scythe
ScytheVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, ScytheVisuals.Settings)
end

return ScytheVisuals
