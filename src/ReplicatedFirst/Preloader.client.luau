--@ Preloader
--@ Runs in ReplicatedFirst to block game load until all Storage assets are ready

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PRELOADABLE_CLASSES = {
	Animation      = true,
	Sound          = true,
	ImageLabel     = true,
	ImageButton    = true,
	Decal          = true,
	ParticleEmitter = true,
	Texture        = true,
	MeshPart       = true,
	SpecialMesh    = true,
}

local Storage = ReplicatedStorage:WaitForChild("Storage")

local Preloadables = {}
for _, Asset in Storage:GetDescendants() do
	if PRELOADABLE_CLASSES[Asset.ClassName] then
		table.insert(Preloadables, Asset)
	end
end

if #Preloadables == 0 then
	warn("[Preloader]: No preloadable assets found in Storage.")
	return
end

warn(string.format("[Preloader]: Preloading %d assets...", #Preloadables))

local PreloadStart = os.clock()

local Failed = 0
ContentProvider:PreloadAsync(Preloadables, function(assetId, status)
	if status ~= Enum.AssetFetchStatus.Success then
		Failed += 1
		warn(string.format("[Preloader]: Failed to preload '%s' (%s)", assetId, status.Name))
	end
end)

local PreloadTime = os.clock() - PreloadStart
warn(string.format("[Preloader]: Preloaded %d assets in %.2fs (%d failed).", #Preloadables - Failed, PreloadTime, Failed))
