-- Created Date: Thursday November 23rd 2023 3:14:04 pm CEST
-- Original Author: Jurian Vierbergen at <VoidedBlades (Rbx), @VoidedBlades (Twitter)> ( Shoutout my boy)

local function Visualize(Data)
	if not Data.Debug then
		return
	end

	local Identifier = Data.Identifier
	local Cframe = Data.CFrame
	local Radius = Data.Radius

	local Effect
	if workspace.Terrain:FindFirstChild(Identifier .. "SPHERE") then
		Effect = workspace.Terrain:FindFirstChild(Identifier .. "SPHERE")
		Effect.CFrame = Cframe
		Effect.Radius = Radius
	else
		Effect = Instance.new("SphereHandleAdornment")
		Effect.Name = Identifier .. "SPHERE"
		Effect.Transparency = 0.4
		Effect.CFrame = Cframe
		Effect.Radius = Radius
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

return function(Data, whitelist, blacklist, filterType)
	local Attacker = Data.Attacker

	local HitboxPart = Data.HitboxPart

	if not Data.CFrame and Data.IsAttachment == nil then
		Data.IsAttachment = HitboxPart:IsA("Attachment")
	end

	local MaxTargets = Data.MaxTargets or -1
	local Offset = Data.Offset or Vector3.zero
	local Radius = Data.Radius
	local isDestructible = Data.isDestructible or false

	local TempResults = {}
	local results = {}
	local hitboxCFrame = if Data.CFrameType == "function" then Data.CFrame() else Data.CFrame
	local AttackCFrame = hitboxCFrame or (Data.IsAttachment and HitboxPart.WorldCFrame or HitboxPart.CFrame)

	if typeof(Offset) == "CFrame" then
		AttackCFrame *= Offset
	elseif typeof(Offset) == "Vector3" then
		AttackCFrame *= CFrame.new(Offset)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = filterType or Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = whitelist
	overlapParams.CollisionGroup = Data.CollisionGroup or "HitboxFunction"

	task.defer(function()
		Visualize({ Radius = Radius, CFrame = AttackCFrame, Identifier = tostring(Data), Debug = Data.Debug })
	end)

	local Results = workspace:GetPartBoundsInRadius(AttackCFrame.Position, Radius, overlapParams)

	if Results then
		for _, Part: BasePart in Results do
			local Model = GetTopModel(Part) or Part

			if table.find(blacklist, Model) then
				continue
			end

			if Model then
				if Model == Attacker then
					continue
				end

				if not table.find(TempResults, Model) then
					table.insert(TempResults, Model)
				end
			end
		end

		if #TempResults >= 2 then
			table.sort(TempResults, function(prev: Model, curr: Model)
				local prevpart, currpart

				if prev:IsA("BasePart") then
					prevpart = prev
				elseif prev:IsA("Model") then
					prevpart = prev.PrimaryPart or prev:FindFirstChildWhichIsA("BasePart", true)
				elseif prev:IsA("Folder") then
					prevpart = prev:FindFirstChildWhichIsA("BasePart", true)
				end

				if curr:IsA("BasePart") then
					currpart = curr
				elseif curr:IsA("Model") then
					currpart = curr.PrimaryPart or curr:FindFirstChildWhichIsA("BasePart", true)
				elseif curr:IsA("Folder") then
					currpart = curr:FindFirstChildWhichIsA("BasePart", true)
				end

				local hitboxPos = (Data.CFrame or (Data.IsAttachment and HitboxPart.WorldCFrame or HitboxPart.CFrame)).Position
				local HitboxToTargetOffset = (hitboxPos - prevpart.Position)
				local HitboxToTarget2Offset = (hitboxPos - currpart.Position)

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
			for i = 1, math.clamp(MaxTargets, 0, #TempResults) do
				table.insert(results, TempResults[i])
			end
		end
	end

	return results
end
