local DodgeVisuals = {}

local VisualsCore = require(script.Parent.Parent.Combat.VisualsCore)

DodgeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/MovementVFX/Dodge",
	Parent = "Workspace/World/Visuals",

	--@ The assets author SyncPosition per emitter; false leaves those flags alone.
	SyncPosition = false,

	Lifetime = 3,

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

	local assets = Info.GetPath:ReadPath(settings.Assets)
	local asset = assets and assets:FindFirstChild(assetName)

	if not asset then return end

	task.delay(asset:GetAttribute("EmitDelay") or 0, function()
		if not root.Parent then return end

		VisualsCore.SpawnEffect(Info, settings, asset, root)
	end)
end

return DodgeVisuals
