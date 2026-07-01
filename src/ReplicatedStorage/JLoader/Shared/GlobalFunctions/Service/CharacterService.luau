--@ Character Service
local Utils = {}

--@ Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--@ Imports
local Jloader = require(ReplicatedStorage.JLoader)
local GlobalFunctions = Jloader.GlobalFunctions

local Signal = GlobalFunctions.Signal
local WorldConstants = GlobalFunctions.WorldConstants
local Gizmo = GlobalFunctions.Gizmo

local BODYMOVER_TYPES = {
	"BodyPosition",
	"BodyVelocity"
}

function Utils.GetCFrame(character: Model, client_check: boolean)
	if not character then return CFrame.new() end

	local root: BasePart = character:FindFirstChild("HumanoidRootPart")
	if not root then return CFrame.new() end

	local final_cframe = root.CFrame

	if RunService:IsServer() and client_check then
		local Controller = GlobalFunctions.ServerController:GetProfile(character);

		if Controller and Controller._IsPlayer then
			final_cframe = Controller.ClientProperties.CFrame
		end
	end

	return final_cframe
end

function Utils.IsGrounded(character: Model, amplifier: number)
	amplifier = amplifier or 1
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local humanoid: Humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local origin = Utils.GetCFrame(character)
	--local origin_right = origin + root.CFrame.RightVector * root.Size.X / 2
	--local origin_left = origin - root.CFrame.RightVector * root.Size.X / 2
	local direction = Vector3.new(0, -(root.Size.Y + humanoid.HipHeight) * amplifier, 0) --  * 2

	local is_state_true = false -- if humanoid:GetState() == Enum.HumanoidStateType.Running or humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding then {Material = humanoid.FloorMaterial} else nil
	local result = workspace:Blockcast(origin, root.Size, direction, WorldConstants.world_ray_params)
	if not result then
		if root:GetAttribute("isLowerIn") then return {} end
	end

	return is_state_true or result-- or workspace:Raycast(origin, direction, WorldConstants.world_ray_params) or workspace:Raycast(origin_right, direction, WorldConstants.world_ray_params) or workspace:Raycast(origin_left, direction, WorldConstants.world_ray_params)
end

function Utils.ClearPhysics(Character : Model)
	if not Character then return end;
	
	local HumanoidRootPart : BasePart = Character.HumanoidRootPart or Character.PrimaryPart
	if not HumanoidRootPart then return end

	for _, mover in HumanoidRootPart:GetChildren() do
		if mover.Name == "@impulse_velocity" then
			mover:Destroy()
		end
	end
end

function Utils.FaceCamera(Character : Model)		
	if not Character then return end
	local CurrentCamera = workspace.CurrentCamera

	local HumanoidRootPart : BasePart = Character.HumanoidRootPart or Character.PrimaryPart
	if not HumanoidRootPart then return end

	CurrentCamera = workspace.CurrentCamera

	local lookVector = CurrentCamera.CFrame.LookVector
	lookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

	Character:PivotTo(CFrame.new(HumanoidRootPart.CFrame.Position, HumanoidRootPart.CFrame.Position + lookVector))
end

function Utils.OnGroundTouched(character: Model)
	local ground_touched_signal = Signal.new()

	task.spawn(function()
		local is_grounded = Utils.IsGrounded(character, 1.5)

		local start = os.clock()
		local max_wait = 1
		while character and character.Parent and is_grounded do
			is_grounded = Utils.IsGrounded(character)
			if not is_grounded then break end

			if os.clock() - start > max_wait then break end
			RunService.Heartbeat:Wait()
		end

		local is_grounded = Utils.IsGrounded(character)
		while character and character.Parent and not is_grounded do
			is_grounded = Utils.IsGrounded(character)
			if is_grounded then break end

			RunService.Heartbeat:Wait()
		end

		ground_touched_signal:Fire(is_grounded)
	end)

	return ground_touched_signal
end

function Utils.MinimumHeight(character: Model, height: number)
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin = root.Position
	local direction = Vector3.new(0, -height * 1.5, 0)
	
	local result = workspace:Blockcast(root.CFrame, root.Size, direction, WorldConstants.world_ray_params)
	return if not result then true elseif result and result.Distance >= height then true else false
end

function Utils:GetHumanoid(character)
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid") or character.Parent:FindFirstChildOfClass("Humanoid")
end

function Utils:GetAlivePlayerHumanoid(player: Player)
	local humanoid = Utils:GetPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

function Utils:GetAlivePlayerRootPart(player: Player)
	local humanoid = Utils:GetPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid.RootPart
end

function Utils:GetPlayerRootPart(player: Player)
	local humanoid = Utils:GetPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return humanoid.RootPart
end

function Utils:UnequipTools(player: Player)
	local humanoid = Utils:GetPlayerHumanoid(player)
	if humanoid then
		humanoid:UnequipTools()
	end
end

function Utils:GetPlayerFromCharacter(descendant: Instance)
	local character = descendant
	local player = Players:GetPlayerFromCharacter(character)

	while not player do
		if character and character.Parent then
			character = character.Parent
			player = Players:GetPlayerFromCharacter(character)
		else
			return nil
		end
	end

	return player
end

function Utils:GetMassOfModel(character : Model)
	local mass = 0

	for i, v in pairs(character:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("UnionOperation") then
			mass = mass + v:GetMass()
		end
	end

	return mass
end

function Utils:CharacterTransparency(Character: Model, Toggle: boolean, Duration: number)
	if not Character then return end
	--@ Iterate through all descendants of the character
	
	for _, v in pairs(Character:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) then
			if Toggle then
				--@ Set transparency to 1 if toggling on and not already fully transparent
				
				if v.Transparency ~= 1 then
					v.Transparency = 1

					--@ Reset transparency after the specified duration
					if Duration then
						task.delay(Duration, function()
							v.Transparency = 0
						end)
					end
				end
			else
				
				--@ Set transparency to 0 if toggling off and not already fully opaque
				
				if v.Transparency ~= 0 then
					v.Transparency = 0
				end
			end
		end
	end
end


-- Cosmo
function Utils:CreateBodyMover(Part: BasePart, bodyMoverType: string, properties: {}, duration: number?, updateIfExists: boolean?)
	local PartToParentTo = Part
	
	local existingMover = nil

	--@ Check if a body mover of the given type already exists
	for _, mover in ipairs(PartToParentTo:GetChildren()) do
		if mover:IsA(bodyMoverType) then
			existingMover = mover
			break
		end
	end

	if existingMover then
		--@ If updateIfExists is true, update the existing body mover's properties
		if updateIfExists then
			for property, value in pairs(properties) do
				existingMover[property] = value
			end

			if duration then
				task.delay(duration, function()
					if existingMover then
						existingMover:Destroy()
					end
				end)
			end

			return existingMover
		else
			--@ If updateIfExists is false, destroy the existing body mover
			existingMover:Destroy()
		end
	end

	--@ Create a new body mover
	local newBodyMover = Instance.new(bodyMoverType)
	for property, value in pairs(properties) do
		newBodyMover[property] = value
	end

	newBodyMover.Parent = PartToParentTo

	if duration then
		task.delay(duration, function()
			if newBodyMover then
				newBodyMover:Destroy()
			end
		end)
	end

	return newBodyMover
end

function Utils:ClearBodyMovers(character: Model, whitelist: {}?, blacklist: {}?)
	local humRoot = character.HumanoidRootPart
	
	for _, bodyMover in ipairs(humRoot:GetChildren()) do
		if BODYMOVER_TYPES[bodyMover.ClassName] then
			if whitelist and not whitelist[bodyMover.Name] then
				continue
			end
			
			if blacklist and blacklist[bodyMover.Name] then
				continue
			end
			
			bodyMover:Destroy()
		end
	end
end

return Utils