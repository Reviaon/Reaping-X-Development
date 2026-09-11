-- @ragdoll
local ragdoll = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- // Modules
local dependancies = script:WaitForChild("@dependancies")
local worker = require(dependancies.worker)
local trove = require(dependancies.Trove)

-- // Variables
local is_server = RunService:IsServer()

local config = script:WaitForChild("@config") 

-- @work
if is_server then
	-- // PUBLIC Functions
	function ragdoll.Setup(character: Model)
		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		-- @setup ragdoll
		worker:Setup(character)
		
		-- @setup collisions
		local no_colls_folder = Instance.new("Folder")
		no_colls_folder.Name = "@no_coll"
		no_colls_folder.Parent = character

		local no_colls_map = {}

		local limbs = {
			character:FindFirstChild("Right Arm"),
			character:FindFirstChild("Left Arm"),
			character:FindFirstChild("Right Leg"),
			character:FindFirstChild("Left Leg"),
			character:FindFirstChild("Hitbox_Right Arm"),
			character:FindFirstChild("Hitbox_Left Arm"),
			--character:FindFirstChild("Hitbox_Right Leg"),
			--character:FindFirstChild("Hitbox_Left Leg"),
		}

		local class = {}

		class.Enable = function()
			character.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(.7, .5, .5, 1, .5)
			character.Head.CanCollide = true
			character.HumanoidRootPart.CanCollide = false
			character.RagdollTrigger.Value = true

			if humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end

			for _, limb_1 in ipairs(limbs) do
				for _, limb_2 in ipairs(limbs) do
					if limb_1 == limb_2 then continue end
					
					local no_coll = Instance.new("NoCollisionConstraint")
					no_coll.Part0 = limb_1
					no_coll.Part1 = limb_2
					no_coll.Parent = no_colls_folder
					table.insert(no_colls_map, no_coll)
				end
			end

			character:FindFirstChild("Torso").CanCollide = true

			if character.HumanoidRootPart:HasTag("active_ragdoll") then return end
			character.HumanoidRootPart:AddTag("active_ragdoll")
		end

		class.Disable = function()
			character.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(.7, .5, .5, 1, 100)
			character.Head.CanCollide = false
			character.HumanoidRootPart.CanCollide = true
			character.RagdollTrigger.Value = false
			if humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			
			for _, no_coll in ipairs(no_colls_map) do
				no_coll:Destroy()
			end
			table.clear(no_colls_map)

			character.HumanoidRootPart:RemoveTag("active_ragdoll")
		end

		character.RagdollTrigger.Changed:Connect(function()
			if character.RagdollTrigger.Value then
				class.Enable()
			else
				class.Disable()			
			end
		end)

		return class
	end
else
	-- // PUBLIC Functions
	function ragdoll.Setup(character: Model)
		if config.CustomStateHandling.Value then return end -- @state is being handled customly
		
		local _trove = trove.new()
		_trove:AttachToInstance(character)
		
		local humanoid: Humanoid = character:WaitForChild("Humanoid")
		
		_trove:Add(CollectionService:GetInstanceAddedSignal("active_ragdoll"):Connect(function(part)
			if not part:IsDescendantOf(character) then return end
			if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then return end
			
			humanoid.AutoRotate = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end))
		
		_trove:Add(CollectionService:GetInstanceRemovedSignal("active_ragdoll"):Connect(function(part)
			if not part:IsDescendantOf(character) then return end
			if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then return end
			
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			humanoid.AutoRotate = true
		end))
		
		_trove:Add(config.CustomStateHandling.Changed:Connect(function()
			if not config.CustomStateHandling.Value then return end
			_trove:Destroy()
			
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			humanoid.AutoRotate = true
		end))
	end
end

-- @done
return ragdoll