local TridentVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

TridentVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Trident",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Trident
	Frames = { 25, 27, 25 },
	AfterImage = {},

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {},
}

--@ Handles Combat Visuals For Trident
TridentVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, TridentVisuals.Settings)
end

--@ Plays a named one-shot from Settings.OneShots, independent of the combo
TridentVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, TridentVisuals.Settings)
end

return TridentVisuals
