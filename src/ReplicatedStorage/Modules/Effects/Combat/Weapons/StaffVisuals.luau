local StaffVisuals = {}

local VisualsCore = require(script.Parent.Parent.VisualsCore)

StaffVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Staff",
	Parent = "Workspace/World/Visuals",
	Weapon = "Meshes/diamond stafflow", --@ Afterimage source part name, matching the rig's Motor6D

	Prefix = "Attack", --@ Asset child name is Prefix .. comboIndex

	SyncPosition = true, --@ Forge re-reads the origin each frame so the effect rides the character

	Lifetime = 3,
	FPS = 60,

	--@ impulse_delay x 60fps, from Libraries/WeaponsLibrary/Staff. 1 and 5 are held a frame
	--@ early (31 and 26 derived) - hand-tuned, do not regenerate.
	Frames = { 30, 28, 29, 15, 25 },
	AfterImage = { [1] = 15, [3] = 9 },

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {},
}

--@ Handles Combat Visuals For Staff
StaffVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, StaffVisuals.Settings)
end

--@ Plays a named one-shot from Settings.OneShots, independent of the combo
StaffVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, StaffVisuals.Settings)
end

return StaffVisuals
