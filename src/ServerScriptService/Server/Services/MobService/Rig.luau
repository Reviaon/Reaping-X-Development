local Rig = {}

Rig.Settings = {
	Strip = { "AnimSaves", "InitialPoses" },
	RootName = "HumanoidRootPart",
	JointName = "MobRootJoint",
	FacingName = "MobFacing",
	FacingAttachmentName = "MobFacingAttachment",
	RootHeightAttribute = "MobRootHeight",
	HipHeightAttribute = "MobHipHeight",
	BodyHalfLengthAttribute = "MobBodyHalfLength",
	BodyRadiusAttribute = "MobBodyRadius",
	DefaultBodyLengthRatio = 0.8,
	DefaultRootScale = Vector3.new(0.7, 0.35, 0.5),
	DefaultHipRatio = 0.3,
	DefaultTurnResponsiveness = 18,
	DisabledStates = {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.PlatformStanding,
		Enum.HumanoidStateType.Flying,
		Enum.HumanoidStateType.StrafingNoPhysics,
		Enum.HumanoidStateType.GettingUp,
	},
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function lowestPoint(model: Model): number
	local lowest = math.huge

	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end

		local frame, size = part.CFrame, part.Size
		local extent = math.abs(frame.RightVector.Y) * size.X + math.abs(frame.UpVector.Y) * size.Y + math.abs(frame.LookVector.Y) * size.Z
		lowest = math.min(lowest, part.Position.Y - extent / 2)
	end

	return lowest
end

local function strip(model: Model)
	for _, name in Rig.Settings.Strip do
		local found = model:FindFirstChild(name)

		if found then
			found:Destroy()
		end
	end

	for _, child in model:GetChildren() do
		if child:IsA("AnimationController") or child:IsA("Humanoid") then
			child:Destroy()
		end
	end
end

local function settle(model: Model)
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end

		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanTouch = false
	end
end

local function buildRoot(model: Model, base: BasePart, config)
	local settings = Rig.Settings
	local rigConfig = config.rig or {}
	local bounds, size = model:GetBoundingBox()

	local rootSize = size * (rigConfig.root_scale or settings.DefaultRootScale)
	local hipHeight = size.Y * (rigConfig.hip_ratio or settings.DefaultHipRatio)
	local center = Vector3.new(bounds.Position.X, lowestPoint(model) + hipHeight + rootSize.Y / 2, bounds.Position.Z)
	local look = flat(base.CFrame.LookVector)

	local root = Instance.new("Part")
	root.Name = settings.RootName
	root.Size = rootSize
	root.CFrame = CFrame.lookAt(center, center + (if look.Magnitude > 0 then look.Unit else Vector3.zAxis))
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = true
	root.Massless = false
	root.RootPriority = 127
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth

	local joint = Instance.new("Motor6D")
	joint.Name = settings.JointName
	joint.Part0 = root
	joint.Part1 = base
	joint.C0 = root.CFrame:ToObjectSpace(base.CFrame)
	joint.Parent = root

	local attachment = Instance.new("Attachment")
	attachment.Name = settings.FacingAttachmentName
	attachment.Parent = root

	local facing = Instance.new("AlignOrientation")
	facing.Name = settings.FacingName
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = attachment
	facing.MaxTorque = math.huge
	facing.Responsiveness = config.turn_responsiveness or settings.DefaultTurnResponsiveness
	facing.MaxAngularVelocity = config.turn_speed or math.huge
	facing.Enabled = false
	facing.Parent = root

	root.Parent = model
	model.PrimaryPart = root

	local bodyRadius = size.X / 2
	local bodyLength = size.Z * (rigConfig.body_length_ratio or settings.DefaultBodyLengthRatio)

	model:SetAttribute(settings.RootHeightAttribute, hipHeight + rootSize.Y / 2)
	model:SetAttribute(settings.HipHeightAttribute, hipHeight)
	model:SetAttribute(settings.BodyRadiusAttribute, bodyRadius)
	model:SetAttribute(settings.BodyHalfLengthAttribute, math.max(bodyLength / 2 - bodyRadius, 0))

	return hipHeight
end

local function buildHumanoid(model: Model, hipHeight: number)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hipHeight
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	humanoid.Parent = model
end

function Rig.Prepare(template: Model, config): Model
	local prototype = template:Clone()
	local base = prototype.PrimaryPart

	if not base then
		prototype:Destroy()
		error(`[MobService] Mob template "{template:GetFullName()}" needs a PrimaryPart to build its rig on.`, 2)
	end

	strip(prototype)

	if config.scale and config.scale ~= 1 then
		prototype:ScaleTo(config.scale)
	end

	settle(prototype)
	buildHumanoid(prototype, buildRoot(prototype, base, config))

	return prototype
end

function Rig.Spawn(prototype: Model, ground: Vector3, yaw: number?): Model
	local model = prototype:Clone()
	local height = prototype:GetAttribute(Rig.Settings.RootHeightAttribute) or 0
	local position = ground + Vector3.new(0, height, 0)

	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0))

	return model
end

function Rig.Activate(model: Model, humanoid: Humanoid)
	for _, state in Rig.Settings.DisabledStates do
		humanoid:SetStateEnabled(state, false)
	end

	humanoid.HipHeight = model:GetAttribute(Rig.Settings.HipHeightAttribute) or humanoid.HipHeight
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
end

function Rig.Body(model: Model)
	local settings = Rig.Settings

	return {
		HalfLength = model:GetAttribute(settings.BodyHalfLengthAttribute) or 0,
		Radius = model:GetAttribute(settings.BodyRadiusAttribute) or 1,
	}
end

function Rig.Facing(root: BasePart): AlignOrientation?
	return root:FindFirstChild(Rig.Settings.FacingName) :: AlignOrientation?
end

return Rig
