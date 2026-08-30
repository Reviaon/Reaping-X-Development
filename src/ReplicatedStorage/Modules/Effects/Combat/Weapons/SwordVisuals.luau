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
	Frames = { 27, 33, 23, 48 },
	AfterImage = {},

	--@ Extra visuals keyed by combo index or by name - spec schema in VisualsCore
	OneShots = {
		--@ Singular slash arc on the final swing, welded to the root a frame ahead of Hit4
		[4] = { Asset = "Hit4Slash", Frame = 14, Weld = true },
	},
}

--@ Handles Combat Visuals For Sword
SwordVisuals.Attack = function(controller)
	VisualsCore.Attack(controller, SwordVisuals.Settings)
end

--@ Plays a named one-shot from Settings.OneShots, independent of the combo
SwordVisuals.OneShot = function(controller)
	VisualsCore.OneShot(controller, SwordVisuals.Settings)
end

return SwordVisuals
