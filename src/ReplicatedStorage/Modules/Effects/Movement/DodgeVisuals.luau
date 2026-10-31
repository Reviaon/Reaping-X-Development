local DodgeVisuals = {}

local VisualsCore = require("../Combat/VisualsCore")
local DashDebris = require("./DashDebris")

DodgeVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/MovementVFX/Dodge",
	Parent = "Workspace/World/Visuals",

	SyncPosition = false,

	Lifetime = 3,
	Sustain = "Recolor",

	Recolor = "Recolor",
	RecolorPart = "Torso",

	Directions = {
		W = "FrontDash",
		S = "BackDash",
		A = "LeftDash",
		D = "RightDash",
	},
}

local active = setmetatable({}, { __mode = "k" })

local function replace(character: Model)
	local entry = active[character]

	if entry then
		if entry.Emission then
			entry.Emission:Clear()
		end

		if entry.Effect then
			entry.Effect:Destroy()
		end
	end

	entry = {}
	active[character] = entry

	return entry
end

DodgeVisuals.Dodge = function(Info)
	local settings = DodgeVisuals.Settings
	local character = Info.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local assetName = settings.Directions[Info.Direction]

	if not root or not assetName then return end

	if not Info.Redirect then
		DashDebris.Trail(Info)
	end

	local assets = Info.GetPath:ReadPath(settings.Assets)
	local asset = assets and assets:FindFirstChild(assetName)

	if not asset then return end

	local entry = replace(character)
	local delay = Info.Redirect and 0 or asset:GetAttribute("EmitDelay") or 0
	local sustain = typeof(Info.Duration) == "number" and {
		Name = settings.Sustain,
		Duration = Info.Duration - delay,
	} or nil

	local recolorPart = character:FindFirstChild(settings.RecolorPart)
	local recolor = recolorPart and recolorPart:IsA("BasePart") and {
		Name = settings.Recolor,
		Color = recolorPart.Color,
	} or nil

	task.delay(delay, function()
		if not root.Parent or active[character] ~= entry then return end

		entry.Effect, entry.Emission = VisualsCore.SpawnEffect(Info, settings, asset, root, { Sustain = sustain, Recolor = recolor })
	end)
end

return DodgeVisuals
