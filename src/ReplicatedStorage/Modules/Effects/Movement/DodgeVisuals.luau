local DodgeVisuals = {}

local VisualsCore = require("../Combat/VisualsCore")
local DashDebris = require("./DashDebris")

DodgeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/MovementVFX/Dodge",
	Parent = "Workspace/World/Visuals",

	--@ The assets author SyncPosition per emitter; false leaves those flags alone.
	SyncPosition = false,

	Lifetime = 3,

	--@ Emitters of this name stay Enabled until the dash ends (Info.Duration, from DiveComponent)
	Sustain = "AfterimageParticle",

	Directions = {
		W = "FrontDash",
		S = "BackDash",
		A = "LeftDash",
		D = "RightDash",
	},
}

DodgeVisuals.Dodge = function(Info)
	local settings = DodgeVisuals.Settings
	local character = Info.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local assetName = settings.Directions[Info.Direction]

	if not root or not assetName then return end

	DashDebris.Trail(Info)

	local assets = Info.GetPath:ReadPath(settings.Assets)
	local asset = assets and assets:FindFirstChild(assetName)

	if not asset then return end

	local delay = asset:GetAttribute("EmitDelay") or 0
	local sustain = typeof(Info.Duration) == "number" and {
		Name = settings.Sustain,
		Duration = Info.Duration - delay,
	} or nil

	task.delay(delay, function()
		if not root.Parent then return end

		VisualsCore.SpawnEffect(Info, settings, asset, root, { Sustain = sustain })
	end)
end

return DodgeVisuals
