local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RagdollR6 = require("@game/ReplicatedStorage/Libraries/RagdollR6")
local Rig = require("@game/ReplicatedStorage/Libraries/RagdollR6/Rig")
local Simulator = require("@game/ReplicatedStorage/Libraries/RagdollR6/Simulator")
local StatusService = require("../Character/StatusService")

local RagdollService = {}

RagdollService.Settings = {
	Status = "IsRagdolled", --@ Status the ragdoll rides on; every system reads this, never the attributes below
	Profile = "Soft", --@ RagdollR6 profile a rig starts on: Soft (muscles) or Hard (limits only)
	Replication = "Stream", --@ How observers see a ragdoll: Stream (the simulator's pose, buffered) or Native (physics replication)
	EnabledAttribute = "RagdollEnabled", --@ RagdollR6's switch, driven from Status
	IdentityAttributes = { "RagdollId", "RagdollReady" }, --@ Cleared on a copied rig so it gets its own stream id
}

local rigs = setmetatable({}, { __mode = "k" })

local function isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function follow(character: Model)
	local settings = RagdollService.Settings

	character:GetAttributeChangedSignal(settings.Status):Connect(function()
		local ragdolled = character:GetAttribute(settings.Status) == true

		if not ragdolled and not isAlive(character) then return end

		character:SetAttribute(settings.EnabledAttribute, ragdolled)
	end)
end

function RagdollService.Start()
	RagdollR6.Start({
		autoPlayers = false,
		ragdollOnDeath = true,
		replication = RagdollService.Settings.Replication,
	})
end

function RagdollService.Setup(character: Model): boolean
	if not RunService:IsServer() then return false end
	if rigs[character] then return true end
	if not RagdollR6.IsR6(character) then return false end

	RagdollService.Start()

	if not RagdollR6.Setup(character, RagdollService.Settings.Profile) then return false end

	rigs[character] = true
	follow(character)

	return true
end

function RagdollService.Adopt(copy: Model): boolean
	for _, attribute in RagdollService.Settings.IdentityAttributes do
		copy:SetAttribute(attribute, nil)
	end

	CollectionService:RemoveTag(copy, Rig.TAG)

	return RagdollService.Setup(copy)
end

function RagdollService.Ragdoll(character: Model, duration: number)
	if not RunService:IsServer() then return nil end
	if not RagdollService.Setup(character) then return nil end

	local handle = StatusService:ApplyStatus(character, RagdollService.Settings.Status, true, duration)
	character:SetAttribute(RagdollService.Settings.EnabledAttribute, true)

	return handle
end

local function tumble(velocity: Vector3, spin: number?): Vector3?
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if typeof(spin) ~= "number" or spin == 0 or horizontal.Magnitude < 1e-3 then return nil end

	return Vector3.yAxis:Cross(horizontal.Unit) * math.rad(spin)
end

function RagdollService.Launch(character: Model, velocity: Vector3, spin: number?): boolean
	if not isAlive(character) then return false end

	if RunService:IsClient() and character:GetAttribute(RagdollService.Settings.EnabledAttribute) == true then
		local rig = Rig.get(character)

		if rig then
			Simulator.set(rig, true)
		end
	end

	if RagdollR6.Fling(character, velocity, nil, tumble(velocity, spin)) then return true end

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = velocity
		end
	end

	return true
end

function RagdollService.Sever(character: Model, limb: BasePart)
	local folder = character:FindFirstChild(Rig.FOLDER)

	for _, item in folder and folder:GetChildren() or {} do
		local attached = false

		if item:IsA("Constraint") then
			attached = (item.Attachment0 ~= nil and item.Attachment0.Parent == limb) or (item.Attachment1 ~= nil and item.Attachment1.Parent == limb)
		elseif item:IsA("NoCollisionConstraint") then
			attached = item.Part0 == limb or item.Part1 == limb
		end

		if attached then
			item:Destroy()
		end
	end

	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part1 == limb then
			joint:Destroy()
		end
	end
end

function RagdollService.IsRagdolled(character: Model): boolean
	return character:GetAttribute(RagdollService.Settings.Status) == true
end

return RagdollService
