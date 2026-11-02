local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local CorpseLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/CorpseLibrary")

local GlobalFunctions = Jloader.GlobalFunctions

local CorpseService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Basic = { "Replaced" } },
})

local STRIPPED = { "Script", "LocalScript", "ModuleScript", "ForceField", "Sound" }

local successors = setmetatable({}, { __mode = "k" })

local function folder(): Instance
	local found = workspace

	for _, segment in CorpseLibrary.FolderPath do
		local child = found:FindFirstChild(segment)

		if not child then
			child = Instance.new("Folder")
			child.Name = segment
			child.Parent = found
		end

		found = child
	end

	return found
end

local function isDead(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health <= 0
end

local function strip(corpse: Model)
	for _, descendant in corpse:GetDescendants() do
		for _, class in STRIPPED do
			if descendant:IsA(class) then
				descendant:Destroy()
				break
			end
		end
	end

	local humanoid = corpse:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
	end
end

local function keep(character: Model)
	if not isDead(character) or not character:FindFirstChild("Torso") then return end

	local archivable = character.Archivable
	character.Archivable = true

	local corpse = character:Clone()
	character.Archivable = archivable

	if not corpse then return end

	strip(corpse)
	CollectionService:AddTag(corpse, CorpseLibrary.Tag)
	corpse.Parent = folder()

	for _, part in corpse:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(nil)
		end
	end

	successors[character] = corpse
	Debris:AddItem(corpse, CorpseLibrary.Lifetime)

	CorpseService.Replaced:Fire(character, corpse)
end

local function beingEaten(character: Model): boolean
	local feeders = character:GetAttribute(CorpseLibrary.FeedersAttribute)
	local bitAt = character:GetAttribute(CorpseLibrary.BitAttribute)

	if typeof(feeders) == "number" and feeders > 0 and #CorpseService:Limbs(character) > 0 then return true end

	return typeof(bitAt) == "number" and os.clock() - bitAt <= CorpseLibrary.BiteGrace
end

local function respawn(player: Player, character: Model)
	task.wait(CorpseLibrary.RespawnTime)

	local deadline = os.clock() + CorpseLibrary.FeastWatch

	while player.Parent and player.Character == character and os.clock() < deadline and beingEaten(character) do
		task.wait(0.25)
	end

	if player.Parent and player.Character == character then
		player:LoadCharacter()
	end
end

local function watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	humanoid.Died:Once(function()
		CollectionService:AddTag(character, CorpseLibrary.Tag)
		respawn(player, character)
	end)
end

function CorpseService:Resolve(corpse: Model?): Model?
	while corpse and successors[corpse] do
		corpse = successors[corpse]
	end

	return if corpse and corpse.Parent then corpse else nil
end

function CorpseService:GetCorpses(): { Model }
	local found = {}

	for _, corpse in CollectionService:GetTagged(CorpseLibrary.Tag) do
		if corpse:IsA("Model") and corpse.Parent and not successors[corpse] then
			table.insert(found, corpse)
		end
	end

	return found
end

function CorpseService:Limbs(corpse: Model): { string }
	local torso = corpse:FindFirstChild("Torso")
	local names = {}

	if not torso then return names end

	for jointName in CorpseLibrary.Limbs do
		local joint = torso:FindFirstChild(jointName)
		local limb = joint and joint:IsA("Motor6D") and joint.Part1

		if limb and not limb:GetAttribute(CorpseLibrary.TakenAttribute) then
			table.insert(names, jointName)
		end
	end

	return names
end

function CorpseService:Take(corpse: Model, jointName: string, carrier: Model, boneName: string, offset: CFrame): BasePart?
	local torso = corpse:FindFirstChild("Torso")
	local joint = torso and torso:FindFirstChild(jointName)
	local limb = joint and joint:IsA("Motor6D") and joint.Part1

	if not limb or limb:GetAttribute(CorpseLibrary.TakenAttribute) then return nil end

	GlobalFunctions.RagdollService.Sever(corpse, limb)

	corpse:SetAttribute(CorpseLibrary.BitAttribute, os.clock())
	limb:SetAttribute(CorpseLibrary.TakenAttribute, true)
	limb.Anchored = true
	limb.CanCollide = false

	local holder = Instance.new("ObjectValue")
	holder.Name = CorpseLibrary.HolderName
	holder.Value = carrier
	holder.Parent = limb

	limb:SetAttribute(CorpseLibrary.BoneAttribute, boneName)
	limb:SetAttribute(CorpseLibrary.OffsetAttribute, offset)
	CollectionService:AddTag(limb, CorpseLibrary.HeldTag)

	return limb
end

function CorpseService:Find(corpse: Model?, limb: BasePart): BasePart?
	if limb.Parent then return limb end

	corpse = self:Resolve(corpse)
	local found = corpse and corpse:FindFirstChild(limb.Name)

	return if found and found:IsA("BasePart") and found:GetAttribute(CorpseLibrary.TakenAttribute) then found else nil
end

local function letGo(limb: BasePart): (Model?, string?, CFrame?)
	local holder = limb:FindFirstChild(CorpseLibrary.HolderName)
	local carrier = holder and holder:IsA("ObjectValue") and holder.Value
	local boneName = limb:GetAttribute(CorpseLibrary.BoneAttribute)
	local offset = limb:GetAttribute(CorpseLibrary.OffsetAttribute)

	CollectionService:RemoveTag(limb, CorpseLibrary.HeldTag)
	limb:SetAttribute(CorpseLibrary.BoneAttribute, nil)
	limb:SetAttribute(CorpseLibrary.OffsetAttribute, nil)

	if holder then
		holder:Destroy()
	end

	return carrier, boneName, offset
end

function CorpseService:Drop(limb: BasePart)
	local carrier, boneName, offset = letGo(limb)
	local bone = carrier and typeof(boneName) == "string" and carrier:FindFirstChild(boneName, true)

	if bone and bone:IsA("Bone") and typeof(offset) == "CFrame" then
		limb.CFrame = bone.TransformedWorldCFrame * offset
	end

	limb.Anchored = false
	limb.CanCollide = true
	limb.AssemblyLinearVelocity = Vector3.zero

	if limb:CanSetNetworkOwnership() then
		limb:SetNetworkOwner(nil)
	end
end

function CorpseService:Consume(limb: BasePart)
	letGo(limb)

	local corpse = limb.Parent

	for _, accessory in corpse and corpse:GetChildren() or {} do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")

		if weld and (weld.Part0 == limb or weld.Part1 == limb) then
			accessory:Destroy()
		end
	end

	limb:Destroy()
end

function CorpseService:Init()
	Players.CharacterAutoLoads = false

	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)

		player.CharacterRemoving:Connect(keep)

		if player.Character then
			task.spawn(watch, player, player.Character)
		else
			player:LoadCharacter()
		end
	end

	for _, player in Players:GetPlayers() do
		track(player)
	end

	Players.PlayerAdded:Connect(track)
end

return CorpseService
