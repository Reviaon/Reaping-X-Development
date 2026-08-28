local SwordVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

SwordVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Sword",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Sword
	Frames = { 27, 33, 23, 15 },
	AfterImage = {},
}

--@ Handles Combat Visuals For Sword
SwordVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, SwordVisuals.Settings)
end

return SwordVisuals
