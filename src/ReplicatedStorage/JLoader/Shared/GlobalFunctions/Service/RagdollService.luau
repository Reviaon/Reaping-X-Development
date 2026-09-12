local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatusService = require(script.Parent:WaitForChild("StatusService"))

local RagdollService = {}

RagdollService.Settings = {
	--@ Status the ragdoll rides on; its attribute is what every machine reacts to.
	Status = "IsRagdolled",

	--@ Degrees an arm may swing away from hanging straight down.
	ShoulderAngle = 110,

	--@ Degrees a leg may swing away from hanging straight down.
	HipAngle = 70,

	--@ Degrees a limb may twist about its own length, each way.
	TwistAngle = 40,

	--@ Size of each limb's ragdoll collider relative to the limb. Under 1 keeps it clear of the torso at
	--@ rest, so a hanging limb never starts in contact and locks the way a flush limb part does.
	ColliderScale = 0.5,

	--@ Surface of the limb colliders: low friction so a limb resting on the body slides rather than sticks.
	ColliderProperties = PhysicalProperties.new(0.7, 0.2, 0.2),

	--@ Name given to every instance the rig adds.
	RigName = "@ragdoll",
}

local LIMB_JOINTS = {
	["Right Shoulder"] = "ShoulderAngle",
	["Left Shoulder"] = "ShoulderAngle",
	["Right Hip"] = "HipAngle",
	["Left Hip"] = "HipAngle",
}

local HANGING = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))

local rigs = setmetatable({}, { __mode = "k" })

local function attach(parent: BasePart, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = RagdollService.Settings.RigName
	attachment.CFrame = CFrame.new(position) * HANGING
	attachment.Parent = parent
	return attachment
end

local function collider(limb: BasePart, parent: Instance): BasePart
	local settings = RagdollService.Settings
	local part = Instance.new("Part")
	part.Name = settings.RigName
	part.Size = limb.Size * settings.ColliderScale
	part.Transparency = 1
	part.Massless = true
	part.CustomPhysicalProperties = settings.ColliderProperties
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = limb.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part

	part.Parent = parent
	return part
end

local function claimLimbs(rig, owner: Player?)
	for _, joint in rig.joints do
		local limb = joint.limb

		if limb.Parent and limb:CanSetNetworkOwnership() then
			limb:SetNetworkOwner(owner)
		end
	end
end

local function enable(rig)
	if rig.active then return end
	rig.active = true

	rig.rootCollide = rig.root.CanCollide
	rig.rootWeld.Enabled = true
	rig.rootJoint.Enabled = false
	rig.root.CanCollide = false

	--@ In the Physics state the Humanoid stops forcing limbs non-colliding, so they would lock against
	--@ the torso they hang flush with on contact friction; the colliders do their colliding instead.
	for _, joint in rig.joints do
		joint.socket.Enabled = true
		joint.collider.CanCollide = true
		joint.limb.CanCollide = false
		joint.motor.Enabled = false
	end

	local owner = Players:GetPlayerFromCharacter(rig.character)

	if not owner and rig.humanoid.Health > 0 then
		rig.humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	claimLimbs(rig, owner)

	--@ The Humanoid re-enables limb collision on its way into the Physics state, after this ran, so
	--@ it is held off every frame for as long as the ragdoll lasts.
	rig.enforcer = RunService.Heartbeat:Connect(function()
		for _, joint in rig.joints do
			if joint.limb.CanCollide then
				joint.limb.CanCollide = false
			end
		end
	end)

	RunService.Heartbeat:Once(function()
		if rig.active then
			claimLimbs(rig, owner)
		end
	end)
end

local function disable(rig)
	if not rig.active then return end
	rig.active = false

	if rig.enforcer then
		rig.enforcer:Disconnect()
		rig.enforcer = nil
	end

	for _, joint in rig.joints do
		joint.motor.Enabled = true
		joint.socket.Enabled = false
		joint.collider.CanCollide = false
	end

	rig.rootJoint.Enabled = true
	rig.rootWeld.Enabled = false
	rig.root.CanCollide = rig.rootCollide

	if not Players:GetPlayerFromCharacter(rig.character) and rig.humanoid.Health > 0 then
		rig.humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		rig.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function RagdollService.Setup(character: Model)
	if not RunService:IsServer() then return nil end

	local existing = rigs[character]
	if existing then return existing end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	local rootJoint = root and root:FindFirstChild("RootJoint")

	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then return nil end
	if not torso or not rootJoint or not rootJoint:IsA("Motor6D") then return nil end

	local settings = RagdollService.Settings

	local folder = Instance.new("Folder")
	folder.Name = settings.RigName

	local rootWeld = Instance.new("Weld")
	rootWeld.Name = settings.RigName
	rootWeld.Enabled = false
	rootWeld.C0 = rootJoint.C0
	rootWeld.C1 = rootJoint.C1
	rootWeld.Part0 = root
	rootWeld.Part1 = torso
	rootWeld.Parent = folder

	local joints = {}

	for name, limitKey in LIMB_JOINTS do
		local motor = torso:FindFirstChild(name)
		if not motor or not motor:IsA("Motor6D") or not motor.Part1 then continue end

		local limb = motor.Part1

		local socket = Instance.new("BallSocketConstraint")
		socket.Name = settings.RigName
		socket.Enabled = false
		socket.LimitsEnabled = true
		socket.UpperAngle = settings[limitKey]
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -settings.TwistAngle
		socket.TwistUpperAngle = settings.TwistAngle
		socket.Attachment0 = attach(torso, motor.C0.Position)
		socket.Attachment1 = attach(limb, motor.C1.Position)
		socket.Parent = folder

		local part = collider(limb, folder)

		table.insert(joints, { motor = motor, socket = socket, collider = part, limb = limb })
	end

	folder.Parent = character

	local rig = {
		character = character,
		humanoid = humanoid,
		root = root,
		rootJoint = rootJoint,
		rootWeld = rootWeld,
		rootCollide = root.CanCollide,
		joints = joints,
		active = false,
	}

	rigs[character] = rig

	character:GetAttributeChangedSignal(settings.Status):Connect(function()
		if character:GetAttribute(settings.Status) == true then
			enable(rig)
		else
			disable(rig)
		end
	end)

	return rig
end

function RagdollService.Ragdoll(character: Model, duration: number)
	if not RunService:IsServer() then return nil end

	local rig = RagdollService.Setup(character)
	if not rig then return nil end

	local handle = StatusService:ApplyStatus(character, RagdollService.Settings.Status, true, duration)
	enable(rig)

	return handle
end

function RagdollService.IsRagdolled(character: Model): boolean
	return character:GetAttribute(RagdollService.Settings.Status) == true
end

local LIMBS = { "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local random = Random.new()

--@ motion.spin is degrees per second of backward tumble about the axis across the throw;
--@ motion.twist adds that much of it again as a random angular velocity so no two launches turn the
--@ same way; motion.flail is studs per second of random velocity given to each loose limb, plus a
--@ random spin, so the arms and legs leave the torso moving instead of hanging along it. The whole
--@ body still shares the launch velocity, so the tumble reads in the air and not only on landing.
function RagdollService.Launch(character: Model, velocity: Vector3, motion): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	motion = typeof(motion) == "table" and motion or {}

	local spin = math.rad(typeof(motion.spin) == "number" and motion.spin or 0)
	local twist = typeof(motion.twist) == "number" and motion.twist or 0
	local flail = typeof(motion.flail) == "number" and motion.flail or 0

	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			part.AssemblyLinearVelocity = velocity
		end
	end

	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")

	if torso and spin ~= 0 and horizontal.Magnitude > 1e-3 then
		torso.AssemblyAngularVelocity = Vector3.new(0, 1, 0):Cross(horizontal.Unit) * spin
			+ random:NextUnitVector() * spin * twist
	end

	for _, name in LIMBS do
		local limb = character:FindFirstChild(name)
		if not limb or not limb:IsA("BasePart") then continue end

		limb.CanCollide = false

		if flail > 0 then
			limb.AssemblyLinearVelocity = velocity + random:NextUnitVector() * flail
			limb.AssemblyAngularVelocity = random:NextUnitVector() * math.max(spin, math.rad(flail * 20))
		end
	end

	return true
end

function RagdollService.Watch(character: Model)
	if not RunService:IsClient() then return nil end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return nil end

	local status = RagdollService.Settings.Status
	local enforcer = nil

	local function apply()
		if character:GetAttribute(status) == true then
			if humanoid.Health <= 0 then return end

			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)

			enforcer = enforcer or RunService.Heartbeat:Connect(function()
				for _, name in LIMBS do
					local limb = character:FindFirstChild(name)

					if limb and limb:IsA("BasePart") and limb.CanCollide then
						limb.CanCollide = false
					end
				end
			end)

			return
		end

		if enforcer then
			enforcer:Disconnect()
			enforcer = nil
		end

		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)

		if humanoid.Health > 0 and humanoid:GetState() == Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	apply()

	return character:GetAttributeChangedSignal(status):Connect(apply)
end

return RagdollService
