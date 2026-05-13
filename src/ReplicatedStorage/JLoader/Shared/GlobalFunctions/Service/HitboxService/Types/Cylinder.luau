-- Created Date: Thursday November 23rd 2023 3:14:04 pm CEST
-- Original Author: Jurian Vierbergen at <VoidedBlades (Rbx), @VoidedBlades (Twitter)> ( Shoutout my boy)

local function Visualize(Data)
	if not Data.Debug then
		return
	end

	local Cframe = Data.CFrame * CFrame.Angles(math.rad(90), 0, 0)
	local Radius = Data.Radius
	local Height = Data.Height
	local Naming = Data.Identifier .. "CYLINDER"

	local Effect
	if workspace.Terrain:FindFirstChild(Naming) then
		Effect = workspace.Terrain:FindFirstChild(Naming)
		Effect.CFrame = Cframe
		Effect.Radius = Radius
		Effect.Height = Height
	else
		Effect = Instance.new("CylinderHandleAdornment")
		Effect.Name = Naming
		Effect.Transparency = 0.4
		Effect.CFrame = Cframe
		Effect.Radius = Radius
		Effect.Height = Height

		Effect.Adornee = workspace.Terrain
		Effect.Parent = workspace.Terrain
	end

	Effect.Color3 = Color3.fromRGB(31, 128, 29)

	task.delay(0.1, function()
		if Effect and Effect.CFrame == Cframe then
			Effect:Destroy()
		end
	end)
end

local function GetTopModel(child: Instance)
	local ancestor = child:FindFirstAncestorOfClass("Model")
	local last = ancestor
	while ancestor do
		if ancestor then
			last = ancestor
		end

		ancestor = ancestor:FindFirstAncestorOfClass("Model")
	end
	return last
end

local function Project(a, normal)
	local normalized = vector.normalize(normal)
	return normalized * vector.dot(normalized, a)
end

local function ProjectPointInPlane(data, pointToProject)
	return (pointToProject - Project(pointToProject - data.Position, data.Normal))
end

local function GetClosesPointOnDisc(a: vector, b: vector, radius)
	local plane = {
		Position = a,
		Normal = vector.normalize(b - a),
	}
	local vProjected = ProjectPointInPlane(plane, b)

	local distSquared = math.sqrt(vector.dot(vProjected, vProjected))
	local isInsideShape = distSquared < math.sqrt(radius)
	if isInsideShape then
		return vProjected, true
	end
	local pointExtremity = plane.Position + vector.normalize(vProjected - plane.Position) * radius
	return pointExtremity, false
end

local function GetclosesPoint(point, size, v)
	local p1 = point - vector.create(0, size.Y / 2, 0)
	local p2 = point + vector.create(0, size.Y / 2, 0)

	local delta = p2 - p1
	local deltaSquared = vector.dot(delta, delta)
	local dist = vector.dot(v - p1, delta)
	if dist <= 0 then
		return GetClosesPointOnDisc(p1, v, size.X)
	elseif dist >= deltaSquared then
		return GetClosesPointOnDisc(p2, v, size.X)
	else
		dist = dist / deltaSquared
		local pointOnLine = p1 + dist * delta
		local pointOnSurfaceLine = pointOnLine + (vector.normalize(v - pointOnLine) * size.X)
		return pointOnSurfaceLine, true
	end
end

local function IsInsideHitbox(from: vector, targetCF, size)
	local point, isInside = GetclosesPoint(targetCF.Position, size, from)
	return isInside
end

return function(Data, whitelist, blacklist, filterType)
	local Attacker = Data.Attacker
	local MaxTargets = Data.MaxTargets or -1
	local HitboxPart = Data.HitboxPart or Attacker:FindFirstChild("HumanoidRootPart")
	local Offset = Data.Offset or Vector3.zero
	local size = Data.Size

	local Radius = size.X
	local Height = size.Y

	local TempResults = {}
	local results = {}

	local hitboxCFrame = if Data.CFrameType == "function" then Data.CFrame() else Data.CFrame
	local AttackCFrame = hitboxCFrame or HitboxPart.CFrame
	if typeof(Offset) == "CFrame" then
		AttackCFrame *= Offset
	elseif typeof(Offset) == "Vector3" then
		AttackCFrame *= CFrame.new(Offset)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = filterType or Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = whitelist
	overlapParams.CollisionGroup = Data.CollisionGroup or "HitboxFunction"

	local Results =
		workspace:GetPartBoundsInBox(AttackCFrame, Vector3.new(Radius * 2, Height, Radius * 2), overlapParams)
	local result: any = Results

	task.defer(function()
		Visualize({
			Radius = Radius,
			Height = Height,
			CFrame = AttackCFrame,
			Attacker = Attacker,
			Debug = Data.Debug,
			Identifier = tostring(Data),
		})
	end)

	if result then
		for _, Part in result do
			local Model: Model = GetTopModel(Part) or Part

			if table.find(blacklist, Model) then
				continue
			end

			if Model and Model == Attacker then
				continue
			end

			if not table.find(TempResults, Model) then
				local direction = vector.normalize(AttackCFrame.Position - Part.Position)

				local directionLocalSpace = Part.CFrame:VectorToObjectSpace(direction)
				local sizeLocalSpace = Part.Size * directionLocalSpace
				local closestPoint = Part.CFrame:PointToWorldSpace(sizeLocalSpace)
				local isInside = IsInsideHitbox(closestPoint, AttackCFrame, size)

				if isInside then
					table.insert(TempResults, Model)
				end
			end
		end
	end

	if #TempResults >= 2 then
		table.sort(TempResults, function(prev, curr)
			local prevIsModel = prev:IsA("Model")
			local currIsModel = curr:IsA("Model")

			local prevPrim = if prevIsModel then prev.PrimaryPart else prev
			local currPrim = if currIsModel then curr.PrimaryPart else curr

			local HitboxToTargetOffset = (HitboxPart.Position - prevPrim.Position)
			local HitboxToTarget2Offset = (HitboxPart.Position - currPrim.Position)

			local Distance1 = vector.dot(HitboxToTargetOffset, HitboxToTargetOffset)
			local Distance2 = vector.dot(HitboxToTarget2Offset, HitboxToTarget2Offset)

			return Distance1 < Distance2
		end)
	end

	if MaxTargets == -1 then
		results = TempResults
	elseif MaxTargets == 1 then
		results = TempResults[1]
	else
		for i = 1, MaxTargets do
			table.insert(results, TempResults[i])
		end
	end

	return results
end
