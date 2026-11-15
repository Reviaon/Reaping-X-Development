local CollectionService = game:GetService("CollectionService")

local Config = require("./Config")
local Build = require("./Build")

local Recover = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function headingOf(frame: CFrame): Vector3
	for _, axis in { frame.LookVector, -frame.UpVector, frame.UpVector } do
		local planar = flat(axis)

		if planar.Magnitude > 0.2 then
			return planar.Unit
		end
	end

	return Vector3.zAxis
end

local function groundBelow(model: Model, origin: Vector3, group: string): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.CollisionGroup = group

	local result = workspace:Raycast(origin + Vector3.yAxis * 2, Vector3.yAxis * -(Config.GroundProbe + 2), params)

	return if result then result.Position else origin
end

function Recover.Body(model: Model): boolean
	local record = Build.Records[model]
	if not record then return false end

	local folder = model:FindFirstChild(Config.FolderName)
	local hips = folder and folder:FindFirstChild(record.first)
	local base = record.base
	local root = record.root

	local body = base.CFrame * record.offset:Inverse()
	local center = if hips and hips:IsA("BasePart") then hips.Position else body.Position
	local ground = groundBelow(model, center, (root or base).CollisionGroup)
	local height = record.height or (root and root.Size.Y / 2) or 0
	local position = Vector3.new(center.X, ground.Y + height, center.Z)
	local stand = CFrame.lookAt(position, position + headingOf(body))

	if folder then
		folder:Destroy()
	end

	for part, properties in record.parts do
		part.CanCollide = properties.CanCollide
		part.Massless = properties.Massless
	end

	if root then
		root.CFrame = stand
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		base.CFrame = stand * record.offset
	end

	for _, joint in record.joints do
		joint.Enabled = true
	end

	for _, constraint in record.constraints do
		if constraint:IsA("AlignOrientation") and constraint.Mode == Enum.OrientationAlignmentMode.OneAttachment then
			constraint.CFrame = stand.Rotation
		end

		constraint.Enabled = true
	end

	Build.Records[model] = nil
	model:SetAttribute(Config.Attribute, nil)
	CollectionService:RemoveTag(model, Config.Tag)

	return true
end

return Recover
