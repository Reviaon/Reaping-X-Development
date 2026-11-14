-- Finds an R6 rig's joints and, on the server, builds the constraints the ragdoll needs. Every
-- constraint stays Enabled for the life of the rig: while a joint is rigid its two parts share an
-- assembly and the solver ignores them, so the only thing a ragdoll toggles is the joint itself.
--
-- R6 motors are rotated (a limb motor hinges about its Z), so the muscle and limit attachments
-- are not the motor's C0/C1. Each joint gets a frame at the motor's pivot with the Torso's axes
-- (`a0` = C0's position, `a1` = C1 * C0.Rotation^-1, so both coincide in the rest pose). Muscle
-- Transforms live in that frame. The pose stream and the exit blend still read and write the
-- Motor6D, in motor space; the stream carries rotations only, so the pivots must stay the motor's.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Profiles = require(script.Parent.Profiles)

local Rig = {}

Rig.TAG = "RagdollR6"
Rig.FOLDER = "RagdollR6Constraints"

local SKELETON = {
	RootJoint = true,
	Neck = true,
	["Right Shoulder"] = true,
	["Left Shoulder"] = true,
	["Right Hip"] = true,
	["Left Hip"] = true,
}

-- Pairs that never collide. Everything jointed to the Torso; the legs touch side by side at rest;
-- a raised arm reaches the head's box (2 studs wide, wider than the visible head). Arms against
-- legs and against each other still collide.
local NO_COLLIDE = {
	{ "Torso", "Head" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Leg" },
	{ "Torso", "Left Leg" },
	{ "Right Leg", "Left Leg" },
	{ "Head", "Right Arm" },
	{ "Head", "Left Arm" },
}

local IS_SERVER = RunService:IsServer()
local cache: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
local nextId = 0

local function findJoints(model: Model, root: BasePart)
	local joints = {}
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		for _, child in part:GetChildren() do
			if not child:IsA("Motor6D") or not SKELETON[child.Name] then
				continue
			end
			local p0, p1 = child.Part0, child.Part1
			if not (p0 and p1 and p0.Parent == model and p1.Parent == model) then
				continue
			end
			local rotInv = child.C0.Rotation:Inverse()
			table.insert(joints, {
				name = child.Name,
				part0 = p0,
				part1 = p1,
				c0 = child.C0,
				c1 = child.C1,
				f0 = CFrame.new(child.C0.Position),
				f1 = child.C1 * rotInv,
				motor = child,
				isRoot = p0 == root,
			})
		end
	end
	table.sort(joints, function(a, b)
		if a.isRoot ~= b.isRoot then
			return a.isRoot
		end
		return a.name < b.name
	end)
	return joints
end

local function ensure(parent: Instance, className: string, name: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	return inst
end

local function ensureAttachment(part: BasePart, name: string, cf: CFrame): Attachment
	local att = ensure(part, "Attachment", name) :: Attachment
	att.CFrame = cf
	att.Parent = part
	return att
end

local function buildNoCollisions(model: Model, folder: Folder)
	for _, pair in NO_COLLIDE do
		local a = model:FindFirstChild(pair[1])
		local b = model:FindFirstChild(pair[2])
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			local name = "NC_" .. pair[1] .. "_" .. pair[2]
			local ncc = ensure(folder, "NoCollisionConstraint", name) :: NoCollisionConstraint
			ncc.Part0 = a
			ncc.Part1 = b
			ncc.Parent = folder
		end
	end
end

-- Writes a profile onto the constraints. Server only: these are replicated properties, written
-- once per profile change, never per frame.
function Rig.applyProfile(rig)
	local model = rig.model
	local profile = Profiles.get(model:GetAttribute("RagdollProfile"))
	local strengthScale = model:GetAttribute("RagdollStrengthScale") or 1
	local dampingScale = model:GetAttribute("RagdollDampingScale") or 1
	for _, j in rig.joints do
		local spec = Profiles.spec(profile, j.name)
		local f0, f1 = Profiles.frames(profile, j.name)
		local l0, l1 = j.a0, j.a1
		if not (f0 == CFrame.identity and f1 == CFrame.identity) then
			l0 = ensureAttachment(j.part0, j.name .. "RagdollL0", j.f0 * f0)
			l1 = ensureAttachment(j.part1, j.name .. "RagdollL1", j.f1 * f1)
		end

		local socket = j.socket
		socket.Attachment0 = l0
		socket.Attachment1 = l1
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.UpperAngle = spec.cone or 45
		socket.TwistLowerAngle = spec.twist and spec.twist[1] or -45
		socket.TwistUpperAngle = spec.twist and spec.twist[2] or 45
		socket.MaxFrictionTorque = spec.friction or 0
		socket.Restitution = spec.restitution or 0
		socket.Enabled = true

		local muscle = j.muscle
		local strength = (spec.strength or 0) * strengthScale
		muscle.AngularStrength = strength
		muscle.AngularDamping = (spec.damping or 1) * dampingScale
		muscle.MaxTorque = spec.maxTorque or 10000
		muscle.Enabled = strength > 0
	end
end

local function readInstances(rig)
	local folder = rig.folder
	for _, j in rig.joints do
		j.a0 = j.part0:FindFirstChild(j.name .. "RagdollA0")
		j.a1 = j.part1:FindFirstChild(j.name .. "RagdollA1")
		j.socket = folder:FindFirstChild(j.name .. "Socket")
		j.muscle = folder:FindFirstChild(j.name .. "Muscle")
		if not (j.a0 and j.a1 and j.socket and j.muscle) then
			return false
		end
	end
	return true
end

local function describe(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if not humanoid or not root or not torso or not torso:IsA("BasePart") then
		return nil
	end
	if model:FindFirstChild("UpperTorso") then
		return nil
	end
	local all = findJoints(model, root)
	local rig = {
		model = model,
		humanoid = humanoid,
		root = root,
		torso = torso,
		joints = {},
		all = all,
		parts = { root, torso },
		rootJoint = nil,
		folder = model:FindFirstChild(Rig.FOLDER),
		id = model:GetAttribute("RagdollId"),
	}
	for _, j in all do
		if j.isRoot then
			rig.rootJoint = j
		else
			table.insert(rig.joints, j)
			table.insert(rig.parts, j.part1)
		end
	end
	if not rig.rootJoint or rig.rootJoint.part1 ~= torso or #rig.joints == 0 then
		return nil
	end
	return rig
end

-- Server: builds (or rebuilds) the ragdoll constraints on an R6 rig. Idempotent. Returns nil for
-- anything that is not R6 (no Torso, an UpperTorso, or no RootJoint from the root to the Torso).
function Rig.setup(model: Model, profileName: string?)
	assert(IS_SERVER, "Rig.setup is server-only")
	local rig = describe(model)
	if not rig then
		warn(`[RagdollR6] {model:GetFullName()} is not an R6 rig (Humanoid, HumanoidRootPart, Torso, RootJoint)`)
		return nil
	end
	rig.humanoid.BreakJointsOnDeath = false
	rig.humanoid.RequiresNeck = false
	-- Every machine must elect the same assembly roots, whole or split, or the receiver drops
	-- the sender's physics.
	rig.root.RootPriority = 127
	for _, j in rig.all do
		if j.part1 ~= rig.root then
			j.part1.RootPriority = 100
		end
		if j.part0 ~= rig.root then
			j.part0.RootPriority = 100
		end
	end
	if profileName then
		model:SetAttribute("RagdollProfile", profileName)
	elseif model:GetAttribute("RagdollProfile") == nil then
		model:SetAttribute("RagdollProfile", Profiles.Default)
	end

	local folder = model:FindFirstChild(Rig.FOLDER) or Instance.new("Folder")
	folder.Name = Rig.FOLDER
	rig.folder = folder

	for _, j in rig.joints do
		j.a0 = ensureAttachment(j.part0, j.name .. "RagdollA0", j.f0)
		j.a1 = ensureAttachment(j.part1, j.name .. "RagdollA1", j.f1)
		local socket = ensure(folder, "BallSocketConstraint", j.name .. "Socket") :: BallSocketConstraint
		socket.Parent = folder
		j.socket = socket
		local muscle = ensure(folder, "AnimationConstraint", j.name .. "Muscle") :: AnimationConstraint
		muscle.Attachment0 = j.a0
		muscle.Attachment1 = j.a1
		muscle.IsKinematic = false
		muscle.LinearStrength = 0
		muscle.MaxForce = 0
		muscle.Parent = folder
		j.muscle = muscle
	end
	buildNoCollisions(model, folder)
	folder.Parent = model

	if not model:GetAttribute("RagdollId") then
		nextId = nextId % 65535 + 1
		model:SetAttribute("RagdollId", nextId)
	end
	rig.id = model:GetAttribute("RagdollId")
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	Rig.applyProfile(rig)
	cache[model] = rig
	model:SetAttribute("RagdollReady", true)
	CollectionService:AddTag(model, Rig.TAG)
	return rig
end

-- Either side: the rig description, or nil until the server has finished building it.
function Rig.get(model: Model)
	local rig = cache[model]
	if rig then
		return rig
	end
	if not model:GetAttribute("RagdollReady") or not CollectionService:HasTag(model, Rig.TAG) then
		return nil
	end
	rig = describe(model)
	if not rig or not rig.folder or not readInstances(rig) then
		return nil
	end
	cache[model] = rig
	return rig
end

function Rig.forget(model: Model)
	cache[model] = nil
end

function Rig.isR6(model: Model): boolean
	return describe(model) ~= nil
end

return Rig
