local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local PreloadHandler = Jloader.CreateHandler({
	Name = script.Name,
	Signals = { "Completed" },
})

--@ Services
local ContentProvider = game:GetService("ContentProvider")

local ASSET_ID_PROPERTY = {
	Animation = "AnimationId",
	Sound = "SoundId",
	ImageLabel = "Image",
	ImageButton = "Image",
	Decal = "Texture",
	ParticleEmitter = "Texture",
	Texture = "Texture",
	MeshPart = "MeshId",
	SpecialMesh = "MeshId",
}

local UNSET_IDS = {
	[""] = true,
	["0"] = true,
	["rbxassetid://0"] = true,
	["rbxasset://0"] = true,
}

local LOAD_TIMEOUT = 10

PreloadHandler.Finished = false
PreloadHandler.Report = { Total = 0, Loaded = 0, Failed = 0, Skipped = 0, Duration = 0 }

local function AwaitGameLoaded(Timeout: number): boolean
	local Elapsed = 0

	while not game:IsLoaded() and Elapsed < Timeout do
		Elapsed += task.wait(0.1)
	end

	return game:IsLoaded()
end

function PreloadHandler:Collect(Root)
	local Assets, Skipped = {}, 0

	for _, Descendant in Root:GetDescendants() do
		local Property = ASSET_ID_PROPERTY[Descendant.ClassName]
		if not Property then continue end

		local Ok, Id = pcall(function() return Descendant[Property] end)
		if Ok and not UNSET_IDS[tostring(Id)] then
			table.insert(Assets, Descendant)
		else
			Skipped += 1
		end
	end

	return Assets, Skipped
end

function PreloadHandler:Load()
	if not AwaitGameLoaded(LOAD_TIMEOUT) then
		warn(`[PreloadHandler]: Game still not loaded after {LOAD_TIMEOUT}s - preloading what has replicated.`)
	end

	local Storage = ReplicatedStorage:WaitForChild("Storage")
	local Assets, Skipped = self:Collect(Storage)

	self.Report.Total = #Assets
	self.Report.Skipped = Skipped

	if #Assets == 0 then
		warn("[PreloadHandler]: No preloadable assets found in Storage.")
		self.Finished = true
		self.Completed:Fire(self.Report)
		return
	end

	local Started = os.clock()
	local Failed = 0

	ContentProvider:PreloadAsync(Assets, function(AssetId, Status)
		if Status ~= Enum.AssetFetchStatus.Success then
			Failed += 1
			warn(`[PreloadHandler]: Failed to preload '{AssetId}' ({Status.Name})`)
		end
	end)

	self.Report.Duration = os.clock() - Started
	self.Report.Failed = Failed
	self.Report.Loaded = #Assets - Failed
	self.Finished = true

	print(string.format(
		"[PreloadHandler]: Preloaded %d/%d assets in %.2fs (%d failed, %d skipped as unset).",
		self.Report.Loaded, self.Report.Total, self.Report.Duration, Failed, Skipped
	))

	self.Completed:Fire(self.Report)
end

function PreloadHandler:Await()
	if self.Finished then return self.Report end

	self.Completed:Wait()
	return self.Report
end

return PreloadHandler
