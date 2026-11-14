local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require("./Config")

local Pose = {}

local bodies: { [Model]: { { bone: Bone, attachment: Attachment, depth: number } } } = {}

local function depthOf(instance: Instance): number
	local depth = 0
	local parent = instance.Parent

	while parent do
		depth += 1
		parent = parent.Parent
	end

	return depth
end

local function collect(model: Model)
	local folder = model:WaitForChild(Config.FolderName, 10)
	if not folder or not model:HasTag(Config.Tag) then return end

	local bones = {}

	for _, bone in model:GetDescendants() do
		if bone:IsA("Bone") and not bones[bone.Name] then
			bones[bone.Name] = bone
		end
	end

	local drives = {}

	for _, attachment in folder:GetDescendants() do
		if attachment:IsA("Attachment") and attachment:GetAttribute(Config.DriveAttribute) then
			local bone = bones[attachment.Name]

			if bone then
				table.insert(drives, { bone = bone, attachment = attachment, depth = depthOf(bone) })
			end
		end
	end

	table.sort(drives, function(a, b)
		return a.depth < b.depth
	end)

	if #drives > 0 and model:HasTag(Config.Tag) then
		bodies[model] = drives
	end
end

local function step()
	for model, drives in bodies do
		if not model.Parent then
			bodies[model] = nil
			continue
		end

		local worlds = {}

		local function worldOf(instance: Instance?): CFrame
			if not instance then return CFrame.identity end

			local known = worlds[instance]
			if known then return known end

			if instance:IsA("Bone") then
				local world = worldOf(instance.Parent) * instance.CFrame * instance.Transform
				worlds[instance] = world
				return world
			end

			if instance:IsA("BasePart") then return instance.CFrame end

			return CFrame.identity
		end

		for _, drive in drives do
			local target = drive.attachment.WorldCFrame
			local bone = drive.bone

			bone.Transform = (worldOf(bone.Parent) * bone.CFrame):Inverse() * target
			worlds[bone] = target
		end
	end
end

local started = false

function Pose.Start()
	if started then return end
	started = true

	CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(collect, model)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(function(model)
		bodies[model] = nil
	end)

	for _, model in CollectionService:GetTagged(Config.Tag) do
		if model:IsA("Model") then
			task.spawn(collect, model)
		end
	end

	RunService.PreRender:Connect(step)
end

return Pose
