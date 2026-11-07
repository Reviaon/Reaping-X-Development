local Config = require("./Config")

local Placement = {}

local CORNERS = {
	Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1),
}

local function rootOf(character: Instance?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function torsoOf(character: Instance): BasePart?
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function ignoreList(): { Instance }
	local list = {}

	for _, path in Config.IgnorePaths do
		local found = workspace

		for _, segment in path do
			found = found and found:FindFirstChild(segment)
		end

		if found then
			table.insert(list, found)
		end
	end

	return list
end

local function rootHeight(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)
	local half = root and root.Size.Y / 2 or 1

	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + half
	end

	local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
	return half + (if leg and leg:IsA("BasePart") then leg.Size.Y else 2)
end

local function floorUnder(position: Vector3, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	local hit = workspace:Raycast(position + Vector3.new(0, Config.ProbeUp, 0), Vector3.new(0, -(Config.ProbeUp + Config.MaxDrop), 0), params)

	return hit and hit.Position.Y or nil
end

local function isBlocked(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	return workspace:Raycast(from, to - from, params) ~= nil
end

local function sceneBox(definition, victimPlaced: CFrame, attackerPlaced: CFrame, floor: number, victimHeight: number): (CFrame, Vector3)
	local bounds = definition.Bounds

	if bounds then
		local margin = Config.BoundsMargin
		local low = Vector3.new(bounds.Min.X - margin, -victimHeight + Config.FootClearance, bounds.Min.Z - margin)
		local high = Vector3.new(bounds.Max.X + margin, bounds.Max.Y + margin, bounds.Max.Z + margin)
		local level = victimPlaced.Rotation + Vector3.new(victimPlaced.X, floor + victimHeight, victimPlaced.Z)

		return level * CFrame.new((low + high) / 2), high - low
	end

	local padding = definition.Padding or Config.Padding
	local a, b = victimPlaced.Position * Vector3.new(1, 0, 1), attackerPlaced.Position * Vector3.new(1, 0, 1)
	local axis = b - a
	local length = axis.Magnitude
	local middle = (a + b) / 2
	local height = Config.SceneHeight - Config.FootClearance
	local orientation = if length > 1e-3 then CFrame.lookAt(middle, middle + axis) else victimPlaced.Rotation + middle

	return orientation.Rotation + Vector3.new(middle.X, floor + Config.FootClearance + height / 2, middle.Z),
		Vector3.new(padding * 2, height, length + padding * 2)
end

local function isLevel(box: CFrame, size: Vector3, floor: number, ignore: { Instance }): boolean
	local x, z = size.X / 2, size.Z / 2

	for _, corner in { Vector3.zero, Vector3.new(x, 0, z), Vector3.new(-x, 0, z), Vector3.new(x, 0, -z), Vector3.new(-x, 0, -z) } do
		local point = box:PointToWorldSpace(corner)
		local found = floorUnder(Vector3.new(point.X, floor, point.Z), ignore)

		if not found or math.abs(found - floor) > Config.StepTolerance then
			return false
		end
	end

	return true
end

local function isClear(box: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	return #workspace:GetPartBoundsInBox(box, size, params) == 0
end

function Placement.Align(definition, victim: CFrame, from: Vector3): (CFrame, CFrame)
	local position = victim.Position
	local toward = (from - position) * Vector3.new(1, 0, 1)

	if toward.Magnitude <= 1e-3 then
		toward = victim.LookVector * Vector3.new(1, 0, 1)
	end

	if definition.Facing == "Away" then
		local facing = CFrame.lookAt(position, position - toward.Unit)

		return facing, facing * CFrame.new(0, 0, definition.Spacing)
	end

	local facing = CFrame.lookAt(position, position + toward.Unit)

	return facing, facing * CFrame.new(0, 0, -definition.Spacing) * CFrame.Angles(0, math.pi, 0)
end

function Placement.Place(definition, attacker: Model, victim: Model): (CFrame?, CFrame?)
	local attackerRoot, victimRoot = rootOf(attacker), rootOf(victim)
	if not attackerRoot or not victimRoot then return nil, nil end

	local ignore = ignoreList()
	local overlapIgnore = table.clone(ignore)
	table.insert(overlapIgnore, workspace.Terrain)

	local victimHeight, attackerHeight = rootHeight(victim), rootHeight(attacker)
	local origin = victimRoot.Position
	local offset = attackerRoot.Position - origin
	local originFloor = floorUnder(origin, ignore)

	if not originFloor then return nil, nil end

	for _, distance in Config.Shifts do
		local directions = if distance > 0 then Config.ShiftDirections else 1

		for step = 0, directions - 1 do
			local angle = step / directions * math.pi * 2
			local base = origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
			if distance > 0 and isBlocked(origin, base, ignore) then continue end

			local floor = floorUnder(base, ignore)

			if not floor or math.abs(floor - originFloor) > Config.StepTolerance then continue end

			local grounded = CFrame.new(base.X, floor + victimHeight, base.Z) * victimRoot.CFrame.Rotation

			for _, yaw in Config.Yaws do
				local from = base + CFrame.Angles(0, math.rad(yaw), 0):VectorToWorldSpace(offset)
				local victimPlaced, attackerPlaced = Placement.Align(definition, grounded, from)

				attackerPlaced = attackerPlaced.Rotation + Vector3.new(attackerPlaced.X, floor + attackerHeight, attackerPlaced.Z)

				local box, size = sceneBox(definition, victimPlaced, attackerPlaced, floor, victimHeight)

				if isLevel(box, size, floor, ignore) and isClear(box, size, overlapIgnore) then
					return victimPlaced, attackerPlaced
				end
			end
		end
	end

	return nil, nil
end

function Placement.Settled(character: Model, from: CFrame?): CFrame?
	local root, torso = rootOf(character), torsoOf(character)
	if not root or not torso then return nil end

	local base = from or root.CFrame
	local joint = root:FindFirstChild("RootJoint") or torso:FindFirstChild("Root")
	local rest = if joint and joint:IsA("Motor6D") then base * joint.C0 * joint.C1:Inverse() else base
	local shift = (torso.Position - rest.Position) * Vector3.new(1, 0, 1)

	if shift.Magnitude < Config.SettleMinimum then return nil end

	local ignore = ignoreList()
	local target = base.Position + shift

	if isBlocked(base.Position, target, ignore) then return nil end

	local floor, baseFloor = floorUnder(target, ignore), floorUnder(base.Position, ignore)
	if not floor or not baseFloor or math.abs(floor - baseFloor) > Config.StepTolerance then return nil end

	local rotation = base.Rotation
	local look = torso.CFrame.LookVector * Vector3.new(1, 0, 1)

	if torso.CFrame.UpVector.Y >= Config.SettleUpright and look.Magnitude > 1e-3 then
		rotation = CFrame.lookAt(Vector3.zero, look.Unit)
	end

	return rotation + Vector3.new(target.X, base.Y + floor - baseFloor, target.Z)
end

function Placement.MeasureBounds(definition, rig: Model): ({ Min: Vector3, Max: Vector3 }, string)
	local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
	local library = game:GetService("ReplicatedStorage").Storage.Animations
	local children = {}

	for _, motor in rig:GetDescendants() do
		if not motor:IsA("Motor6D") or not motor.Part0 or not motor.Part1 or motor.Part1.Parent ~= rig then continue end
		if motor.Part1:GetAttribute(Config.RigPartAttribute) then continue end

		children[motor.Part0.Name] = children[motor.Part0.Name] or {}
		table.insert(children[motor.Part0.Name], motor)
	end

	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge

	local function sweep(name: string?, rootAt: CFrame)
		local animation = name and library:FindFirstChild(name, true)
		if not animation then return end

		local sequence = KeyframeSequenceProvider:GetKeyframeSequenceAsync(animation.AnimationId)

		for _, keyframe in sequence:GetKeyframes() do
			local poses = {}

			for _, pose in keyframe:GetDescendants() do
				if pose:IsA("Pose") then
					poses[pose.Name] = pose.CFrame
				end
			end

			local queue = { { "HumanoidRootPart", rootAt } }

			while #queue > 0 do
				local entry = table.remove(queue)

				for _, motor in children[entry[1]] or {} do
					local placed = entry[2] * motor.C0 * (poses[motor.Part1.Name] or CFrame.identity) * motor.C1:Inverse()
					local half = motor.Part1.Size / 2

					for _, corner in CORNERS do
						local point = placed:PointToWorldSpace(half * corner)
						low, high = low:Min(point), high:Max(point)
					end

					table.insert(queue, { motor.Part1.Name, placed })
				end
			end
		end
	end

	local from = if definition.Facing == "Away" then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	local _, attackerAt = Placement.Align(definition, CFrame.identity, from)

	sweep(definition.Attacker.Intro, attackerAt)
	sweep(definition.Attacker.Loop, attackerAt)
	sweep(definition.Victim.Intro, CFrame.identity)
	sweep(definition.Victim.Loop, CFrame.identity)

	for _, outcome in definition.Outcomes or {} do
		sweep(outcome.Attacker, attackerAt)
		sweep(outcome.Victim, CFrame.identity)
	end

	local function round(vector: Vector3, outward: number): string
		return string.format("Vector3.new(%.1f, %.1f, %.1f)", outward * math.ceil(outward * vector.X * 10) / 10, outward * math.ceil(outward * vector.Y * 10) / 10, outward * math.ceil(outward * vector.Z * 10) / 10)
	end

	return { Min = low, Max = high }, `Bounds = \{ Min = {round(low, -1)}, Max = {round(high, 1)} \},`
end

return Placement
