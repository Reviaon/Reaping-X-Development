--[[@
	**AnimationPreloadService**: warms every clip on the server at boot
	- **Why:** the server fetches a clip the first time it plays one, so that first track starts ~0.25s late
	  - Clients start replicated tracks on time, so a late server track throws paired scenes out of step (the frog's first tongue latch) and late-starts leaps
	- **How:** every Animation under `Config.Folder` is fetched once through `AnimationClipProvider`, `Config.Concurrency` at a time, in the background
]]
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("@self/Config")

local AnimationPreloadService = Jloader.CreateService({ Name = script.Name })

local started = false

local function folder(): Instance?
	local found: Instance? = ReplicatedStorage

	for _, segment in Config.Folder do
		found = if found then found:FindFirstChild(segment) else nil
	end

	return found
end

local function ids(root: Instance): { string }
	local seen = {}
	local list = {}

	for _, animation in root:GetDescendants() do
		if animation:IsA("Animation") and animation.AnimationId ~= "" and not seen[animation.AnimationId] then
			seen[animation.AnimationId] = true
			table.insert(list, animation.AnimationId)
		end
	end

	return list
end

function AnimationPreloadService:Init()
	if started then return end
	started = true

	local root = folder()
	if not root then return end

	local queue = ids(root)
	local nextIndex = 0

	for _ = 1, Config.Concurrency do
		task.spawn(function()
			while true do
				nextIndex += 1
				local id = queue[nextIndex]
				if not id then return end

				pcall(AnimationClipProvider.GetAnimationClipAsync, AnimationClipProvider, id)
			end
		end)
	end
end

return AnimationPreloadService
