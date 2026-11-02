local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local CorpseHandler = Jloader.CreateHandler({ Name = script.Name })

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CorpseLibrary = require(ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("CharacterLibrary"):WaitForChild("CorpseLibrary"))

local bones = setmetatable({}, { __mode = "k" })

local function carry(limb: BasePart)
	local holder = limb:FindFirstChild(CorpseLibrary.HolderName)
	local carrier = holder and holder:IsA("ObjectValue") and holder.Value
	local boneName = limb:GetAttribute(CorpseLibrary.BoneAttribute)
	local offset = limb:GetAttribute(CorpseLibrary.OffsetAttribute)

	if not carrier or not carrier.Parent or typeof(boneName) ~= "string" or typeof(offset) ~= "CFrame" then return end

	local bone = bones[limb]

	if not bone or bone.Name ~= boneName or not bone:IsDescendantOf(carrier) then
		local found = carrier:FindFirstChild(boneName, true)
		bone = if found and found:IsA("Bone") then found else nil
		bones[limb] = bone
	end

	if not bone then return end

	limb.Anchored = true
	limb.CFrame = bone.TransformedWorldCFrame * offset
end

function CorpseHandler:Load()
	RunService.PreRender:Connect(function()
		for _, limb in CollectionService:GetTagged(CorpseLibrary.HeldTag) do
			if limb:IsA("BasePart") then
				carry(limb)
			end
		end
	end)
end

return CorpseHandler
