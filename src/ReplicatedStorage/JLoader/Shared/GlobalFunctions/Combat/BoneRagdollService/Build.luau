local CollectionService = game:GetService("CollectionService")

local Config = require("./Config")

local Build = {}

local function bonesOf(model: Model): { [string]: Bone }
	local bones = {}

	for _, bone in model:GetDescendants() do
		if bone:IsA("Bone") and not bones[bone.Name] then
			bones[bone.Name] = bone
		end
	end

	return bones
end

local function baseOf(bone: Bone): BasePart?
	local parent = bone.Parent

	while parent and not parent:IsA("BasePart") do
		parent = parent.Parent
	end

	return parent
end

local function across(value: unknown, scale: number): Vector2
	if typeof(value) == "Vector2" then return value * scale end
	if typeof(value) == "number" then return Vector2.new(value, value) * scale end

	return Vector2.new(Config.Thickness, Config.Thickness) * scale
end

local function twistOf(value: unknown): (number, number)
	if typeof(value) == "table" then return value[1], value[2] end

	local twist = if typeof(value) == "number" then value else Config.Twist

	return -twist, twist
end

local function segmentFrame(from: Vector3, to: Vector3, base: CFrame): CFrame
	local direction = (to - from).Unit
	local up = if math.abs(direction:Dot(base.UpVector)) > 0.95 then base.LookVector else base.UpVector

	return CFrame.lookAt((from + to) / 2, to, up)
end

local function makeSegment(spec, bones, scale: number, base: CFrame): (BasePart?, CFrame)
	local from, to = bones[spec.from], bones[spec.to]

	if not from or not to then
		warn(`[BoneRagdollService] Segment "{spec.name}" needs bones "{spec.from}" and "{spec.to}"`)
		return nil, CFrame.identity
	end

	local a, b = from.TransformedWorldCFrame.Position, to.TransformedWorldCFrame.Position
	local size = across(spec.across, scale)
	local padding = (spec.padding or Config.Padding) * scale

	local length = math.max((b - a).Magnitude + padding, 0.2)
	local frame = segmentFrame(a, b, base)

	local part = Instance.new("Part")
	part.Name = spec.name

	if spec.round then
		local diameter = (size.X + size.Y) / 2
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(length, diameter, diameter)
		part.CFrame = frame * CFrame.Angles(0, math.pi / 2, 0)
	else
		part.Size = Vector3.new(size.X, size.Y, length)
		part.CFrame = frame
	end

	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CustomPhysicalProperties = Config.Physical
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for _, name in spec.drives or { spec.from } do
		local bone = bones[name]

		if not bone then
			warn(`[BoneRagdollService] Segment "{spec.name}" drives a missing bone "{name}"`)
			continue
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = part.CFrame:ToObjectSpace(bone.TransformedWorldCFrame)
		attachment:SetAttribute(Config.DriveAttribute, true)
		attachment.Parent = part
	end

	return part, frame
end

local function join(spec, parent: BasePart, child: BasePart, axes: CFrame, pivot: Vector3, folder: Folder)
	local frame = CFrame.fromMatrix(pivot, axes.LookVector, axes.UpVector)

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = `{child.Name}Socket`
	attachment0.CFrame = parent.CFrame:ToObjectSpace(frame)
	attachment0.Parent = parent

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = `{child.Name}Socket`
	attachment1.CFrame = child.CFrame:ToObjectSpace(frame)
	attachment1.Parent = child

	local lower, upper = twistOf(spec.twist)

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = child.Name
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.UpperAngle = spec.cone or Config.Cone
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = lower
	socket.TwistUpperAngle = upper
	socket.Restitution = 0
	socket.MaxFrictionTorque = child:GetMass() * (spec.friction or Config.FrictionPerMass)
	socket.Parent = folder
end

local function keepApart(segments: { BasePart }, folder: Folder)
	for i = 1, #segments do
		for j = i + 1, #segments do
			local apart = Instance.new("NoCollisionConstraint")
			apart.Part0 = segments[i]
			apart.Part1 = segments[j]
			apart.Parent = folder
		end
	end
end

local function attach(part: BasePart, to: BasePart, folder: Folder)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Name = part.Name
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = folder
end

local function release(model: Model, root: BasePart?, base: BasePart)
	for _, part in { root, base } do
		if not part then continue end

		for _, joint in part:GetChildren() do
			if joint:IsA("JointInstance") and (joint.Part0 == base or joint.Part1 == base) and joint.Part0 ~= joint.Part1 then
				local other = if joint.Part0 == base then joint.Part1 else joint.Part0

				if other == root or other == base then
					joint.Enabled = false
				end
			end
		end
	end

	for _, constraint in model:GetDescendants() do
		if constraint:IsA("Constraint") and constraint:IsDescendantOf(root or base) then
			constraint.Enabled = false
		end
	end
end

local function pin(model: Model, segments: { BasePart })
	task.spawn(function()
		while model.Parent and model:HasTag(Config.Tag) do
			for _, part in segments do
				if part.Parent and not part.Anchored and part:CanSetNetworkOwnership() then
					part:SetNetworkOwner(nil)
				end
			end

			task.wait(Config.PinInterval)
		end
	end)
end

function Build.Body(model: Model, definition): boolean
	if model:HasTag(Config.Tag) then return true end

	local specs = definition and definition.segments
	if typeof(specs) ~= "table" or #specs == 0 then return false end

	local bones = bonesOf(model)
	local first = bones[specs[1].from]
	local base = first and baseOf(first)

	if not base then
		warn(`[BoneRagdollService] {model:GetFullName()} has no bone "{specs[1].from}" under a part`)
		return false
	end

	local root = model.PrimaryPart
	local velocity = if root then root.AssemblyLinearVelocity else base.AssemblyLinearVelocity
	local scale = model:GetScale()
	local folder = Instance.new("Folder")
	folder.Name = Config.FolderName

	local built: { [string]: BasePart } = {}
	local frames: { [string]: CFrame } = {}
	local segments = {}

	for _, spec in specs do
		local part, frame = makeSegment(spec, bones, scale, base.CFrame)

		if part then
			built[spec.name] = part
			frames[spec.name] = frame
			table.insert(segments, part)
			part.Parent = folder
		end
	end

	local hips = built[specs[1].name]
	if not hips then
		folder:Destroy()
		return false
	end

	for _, spec in specs do
		local child, parent = built[spec.name], spec.parent and built[spec.parent]

		if child and parent then
			join(spec, parent, child, frames[spec.name], bones[spec.from].TransformedWorldCFrame.Position, folder)
		end
	end

	keepApart(segments, folder)
	release(model, root, base)

	attach(base, hips, folder)

	if root and root ~= base then
		attach(root, hips, folder)
	end

	folder.Parent = model

	for _, part in segments do
		part.AssemblyLinearVelocity = velocity
		part.AssemblyAngularVelocity = Vector3.zero
	end

	model:SetAttribute(Config.Attribute, true)
	CollectionService:AddTag(model, Config.Tag)
	pin(model, segments)

	return true
end

return Build
