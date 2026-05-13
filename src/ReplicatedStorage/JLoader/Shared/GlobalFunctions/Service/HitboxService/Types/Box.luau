-- Created Date: Thursday November 23rd 2023 3:14:04 pm CEST
-- Original Author: Jurian Vierbergen at <VoidedBlades (Rbx), @VoidedBlades (Twitter)> ( Shoutout my boy)

local runservice = game:GetService("RunService")

local IS_CLIENT = runservice:IsClient()

local function Visualize(Data)
	local Attacker = Data.Attacker
	local Cframe = Data.Cframe
	local Size = Data.Size

	local Effect: BoxHandleAdornment
	if workspace.Terrain:FindFirstChild(Attacker.Name .. "HITBOX") then
		Effect = workspace.Terrain:FindFirstChild(Attacker.Name .. "HITBOX")
		Effect.CFrame = Cframe
		Effect.Size = Size
		Effect.Color3 = if IS_CLIENT then Color3.fromRGB(0, 150, 255) else Color3.fromRGB(0, 255, 100)
	else
		Effect = Instance.new("BoxHandleAdornment")
		Effect.Name = Attacker.Name .. "HITBOX"
		Effect.Transparency = 0.4
		Effect.CFrame = Cframe
		Effect.Size = Size
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
	local isAttachment = HitboxPart and HitboxPart:IsA("Attachment")

	local MaxTargets = Data.MaxTargets or -1
	local Offset = Data.Offset or Vector3.zero
	local Size = Data.Size
	local isDestructible = Data.isDestructible or false

	local TempResults = {}
	local results = {}
	local hitboxCFrame = if Data.CFrameType == "function" then Data.CFrame() else Data.CFrame

	local AttackCFrame = hitboxCFrame or (isAttachment and HitboxPart.WorldCFrame or HitboxPart.CFrame)

	if typeof(Offset) == "CFrame" then
		AttackCFrame *= Offset
		print(Offset)
	elseif typeof(Offset) == "Vector3" then
		AttackCFrame *= CFrame.new(Offset)
	end

	if typeof(AttackCFrame) == "Vector3" then
		AttackCFrame = CFrame.new(AttackCFrame)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = filterType or Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = whitelist
	overlapParams.CollisionGroup = Data.CollisionGroup or "HitboxFunction"

	if Data.Debug then
		task.defer(function()
			Visualize({ Size = Size, Cframe = AttackCFrame, Attacker = Attacker, Debug = Data.Debug })
		end)
	end

	local Results = workspace:GetPartBoundsInBox(AttackCFrame, Size, overlapParams)

	if Results then
		for _, Part in Results do
			local Model: Model = GetTopModel(Part) or Part	
			--if Part.CollisionGroup ~= "Hitbox" then --@ TODO: Leave this back in
			--	continue
			--end
			
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
			table.sort(TempResults, function(prev, curr)
				local success, respone = pcall(function()
					return prev.PrimaryPart
				end)
				local prevpart = if success then respone else prev

				success, respone = pcall(function()
					return curr.PrimaryPart
				end)
				local currpart = if success then respone else curr

				local hitboxPos = AttackCFrame.Position
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
			for i = 1, MaxTargets do
				table.insert(results, TempResults[i])
			end
		end
	end

	return results
end
