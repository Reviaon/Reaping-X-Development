local module = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PhysicsService = game:GetService("PhysicsService")
local is_server = RunService:IsServer()

function module:Setup(char: Model)
	if char:GetAttribute("ragdoll_setup") then return end
	
	local humanoid = char:FindFirstChild("Humanoid")
	assert(humanoid, "Can only set-up ragdoll on R6 humanoid rigs")
	assert(humanoid.RigType == Enum.HumanoidRigType.R6, "Can only set-up ragdoll on R6 humanoid rigs")
	assert(humanoid.RootPart ~= nil, "No RootPart was found in the provided rig")
	assert(char:FindFirstChild("HumanoidRootPart"), "No HumanoidRootPart was found in the provided rig")
	char:SetAttribute("ragdoll_setup", true)

	local torso = char:WaitForChild("Torso")

	-- @setup
	local folder = Instance.new("Folder")
	folder.Name = "RagdollConstraints"

	-- @right_arm
	local rac = script.RAC.Constraint:Clone()
	rac.Enabled = true

	local rac_a0 = script.RAC.Attachment0:Clone()
	rac_a0.Parent = char:FindFirstChild("Right Arm")

	local rac_a1 = script.RAC.RightAttach:Clone()
	rac_a1.Parent = torso

	rac.Attachment0 = rac_a0
	rac.Attachment1 = rac_a1
	rac.Parent = folder

	-- @left_arm
	local lac = script.LAC.Constraint:Clone()
	lac.Enabled = true

	local lac_a0 = script.LAC.Attachment0:Clone()
	lac_a0.Parent = char:FindFirstChild("Left Arm")

	local lac_a1 = script.LAC.LeftAttach:Clone()
	lac_a1.Parent = torso

	lac.Attachment0 = lac_a0
	lac.Attachment1 = lac_a1
	lac.Parent = folder

	-- @rightleg
	local rlc = script.RLC.Constraint:Clone()
	rlc.Enabled = true

	local rlc_a0 = script.RLC.Attachment0:Clone()
	rlc_a0.Parent = char:FindFirstChild("Right Leg")

	local rlc_a1 = script.RLC.LeftRAttach:Clone()
	rlc_a1.Parent = torso

	rlc.Attachment0 = rlc_a0
	rlc.Attachment1 = rlc_a1
	rlc.Parent = folder

	-- @left_leg
	local llc = script.LLC.Constraint:Clone()
	llc.Enabled = true

	local llc_a0 = script.LLC.Attachment0:Clone()
	llc_a0.Parent = char:FindFirstChild("Left Leg")

	local llc_a1 = script.LLC.LeftLAttach:Clone()
	llc_a1.Parent = torso

	llc.Attachment0 = llc_a0
	llc.Attachment1 = llc_a1
	llc.Parent = folder

	-- @weld
	local ragdoll_weld = Instance.new("Weld")
	ragdoll_weld.Name = "RagdollRootWeld"
	ragdoll_weld.Part1 = torso
	ragdoll_weld.Parent = char.HumanoidRootPart

	-- @done
	folder.Parent = char

	-- @hitbox
	local parts = {"Left Leg", "Right Leg", "Right Arm", "Left Arm"}
	for _, part_name in ipairs(parts) do
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox_".. part_name
		hitbox.Size = Vector3.new(1, .25, 1)
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.Anchored = false
		hitbox.Massless = true
		hitbox.CollisionGroup = "hitbox"
		hitbox.Parent = char
		hitbox:SetAttribute("hitbox", true)

		local weld = Instance.new("Weld")
		weld.Name = "weld"
		weld.Part0 = char:FindFirstChild(part_name)
		weld.Part1 = hitbox
		weld.C0 = CFrame.new(0, -0.850000024, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		weld.Parent = hitbox
	end

	char:WaitForChild("HumanoidRootPart"):SetAttribute("hitbox", true)

	-- @motors
	local folder2 = Instance.new("Folder")
	folder2.Name = "Motors"

	local value
	for _, obj in ipairs(char.Torso:GetChildren()) do
		if obj:IsA("Motor6D") and obj.Name ~= "Neck" then
			value = Instance.new("ObjectValue")
			value.Value = obj
			value.Parent = folder2
		end
	end

	folder2.Parent = folder

	-- @npc support
	if not Players:GetPlayerFromCharacter(char) then
		for _, obj: BasePart in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") and obj:CanSetNetworkOwnership() then
				obj:SetNetworkOwner(nil)
			end
		end
	end

	-- @collisions
	for _, obj: BasePart in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:GetAttribute("hitbox") then
			obj.CollisionGroup = "live"
		end
	end

	-- Setup ragdoll
	char.Head.Size = Vector3.new(1, 1, 1)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	-- Ragdoll trigger
	local trigger = Instance.new("BoolValue")
	trigger.Name = "RagdollTrigger"
	trigger.Parent = char

	trigger.Changed:Connect(function(bool)
		if bool then
			module:Ragdoll(char)
		else
			module:Unragdoll(char)
		end
	end)
end

function module:Ragdoll(char: Model)
	if not char:FindFirstChild("HumanoidRootPart") then return end

	if char.Humanoid.Health > 0 then
		char.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	local RagdollRootWeld: Weld = char.HumanoidRootPart:FindFirstChild("RagdollRootWeld")
	RagdollRootWeld.Part0 = char.HumanoidRootPart

	for _, obj in ipairs(char.RagdollConstraints.Motors:GetChildren()) do
		obj.Value.Enabled = false
	end

	for _, part: BasePart in ipairs(char:GetChildren()) do
		if not part.Name:find("Hitbox_") then continue end
		part.CanCollide = true
	end
end

function module:Unragdoll(char: Model)
	if not char:FindFirstChild("HumanoidRootPart") then return end
	char.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	local RagdollRootWeld: Weld = char.HumanoidRootPart:FindFirstChild("RagdollRootWeld")
	RagdollRootWeld.Part0 = nil

	for _, v in ipairs(char.RagdollConstraints.Motors:GetChildren()) do
		v.Value.Enabled = true
	end

	for _, part: BasePart in ipairs(char:GetChildren()) do
		if not part.Name:find("Hitbox_") then continue end
		part.CanCollide = false
	end
end

return module
