local SpearVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

SpearVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Spear",
	Parent = "Workspace/World/Visuals",
	Weapon = nil, --@ Afterimage source part name; set when the trail is authored

	Prefix = "Hit", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Spear
	Frames = { 28, 33, 34 },
	AfterImage = {},

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {},
}

--@ Handles Combat Visuals For Spear
SpearVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, SpearVisuals.Settings)
end

--@ Plays a named one-shot from Settings.OneShots, independent of the combo
SpearVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, SpearVisuals.Settings)
end

return SpearVisuals
