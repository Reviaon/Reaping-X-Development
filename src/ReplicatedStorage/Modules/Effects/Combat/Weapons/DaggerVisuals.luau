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
	--@ The rig authors this one onto the Right Arm as a Spin attachment, not onto a weapon part
	AfterImage = { [2] = { Frame = 3, Source = "Spin", Within = "Right Arm" } },

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {},
}

--@ Handles Combat Visuals For Dagger
DaggerVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, DaggerVisuals.Settings)
end

--@ Plays a named one-shot from Settings.OneShots, independent of the combo
DaggerVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, DaggerVisuals.Settings)
end

return DaggerVisuals
