local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local CameraHandler = Jloader.CreateHandler({Name = script.Name})

--@ Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--@ Modules
local GlobalFunctions = Jloader.GlobalFunctions
local Spring = GlobalFunctions.Spring
local InputHandler = GlobalFunctions.InputHandler
local MouseModule = GlobalFunctions.MouseModule
local ClientController = GlobalFunctions.ClientController

--@ Constants
local Camera = Workspace.CurrentCamera

local SHIFT_LOCK_OFFSET = Vector3.new(2, 0, 0)
local MOUSE_OBJECT = nil

local TRANSITION_IN_SPEED = 60
local TRANSITION_OUT_SPEED = 30

local ROTATION_SPEED = 20
local USE_SMOOTH_ROTATION = false

--@ Springs
CameraHandler.cameraOffsetSpring = Spring.new(Vector3.zero)
CameraHandler.cameraOffsetSpring.Damper = 1

local shakeSpring = Spring.new(Vector3.zero)
shakeSpring.Damper = 0.8
shakeSpring.Speed = 40

--@ Components
CameraHandler.components = {};

for _, controller: ModuleScript in script:GetDescendants() do
	if controller:IsA("ModuleScript") and controller:GetAttribute("AutoRequire") then
		CameraHandler.components[controller.Name] = require(controller)
	end
end

--@ State
local shiftLockEnabled = false
local inputConnections = {};

local inputActions = {
	Began = {
		[Enum.KeyCode.LeftControl] = {
			canHold = false,
			action = function(controller)
				CameraHandler:ToggleShiftLock(not shiftLockEnabled, controller)
			end,
		} 
	},
	Ended = {

	}
}

function CameraHandler:Init()
	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections, ClientController);
end

function CameraHandler:InitCharacter(controller)
	local Character = controller.Character	

	if not Character then return warn("@CHARACTER FAILED TO LOAD") end

	local _humanoid = Character:WaitForChild("Humanoid")
	local _trove = controller.Trove.new()
	local _mouse = MouseModule.new()

	MOUSE_OBJECT = _mouse
	MOUSE_OBJECT.filterDescendants = {Character, workspace.World.Visuals, workspace.World.Live}

	CameraHandler:ToggleShiftLock(shiftLockEnabled, controller)
	
	_trove:Add(_humanoid.Died:Connect(function()
		CameraHandler:OnCharacterRemoved(controller)
	end))

	_trove:Add(RunService.RenderStepped:Connect(function(DeltaTime : number)
		CameraHandler:UpdateCamera(DeltaTime, controller)
	end))

	warn("CAMERA HANDLER INITIALIZED", controller.Character)
end


function CameraHandler:OnCharacterRemoved(controller)
	CameraHandler:ToggleShiftLock(false, controller)
end

--@ TODO: Refractor this for screen shake capabilities, utilize camera shaker.
function CameraHandler:ShakeCamera(power, decay, amplifier)
	shakeSpring.Position += Vector3.new(
		math.random(-power, power) * amplifier,
		math.random(-power, power) * amplifier,
		math.random(-power, power)
	)
	
	shakeSpring.Damper = decay or 0.8
end

function CameraHandler:ToggleShiftLock(state, controller)
	shiftLockEnabled = state
	UserInputService.MouseBehavior = state and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	CameraHandler.cameraOffsetSpring.Speed = state and TRANSITION_IN_SPEED or TRANSITION_OUT_SPEED
	CameraHandler.cameraOffsetSpring.Target = state and SHIFT_LOCK_OFFSET or Vector3.zero

	local Character = controller.Character
	local Humanoid = Character:WaitForChild("Humanoid")
	local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

	if state then
		controller.StatusService:SetStatus(Character, 
			"ShiftLock", 
			state
		)

		RunService:BindToRenderStep("ShiftLockRotation", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not (Character) then return end

			if not controller.StatusService:CheckStatuses(Character, {NoRotate = true})  
				and not (controller.StatusService:CheckStatuses(Character, {IsSprinting = true}) 
				and not controller.StatusService:CheckStatuses(Character, {IsAttacking = true})) then

				Humanoid.AutoRotate = false
				
				local rootPos = HumanoidRootPart.Position
				local targetCFrame
	
				local _, camY = Camera.CFrame:ToOrientation()
				targetCFrame = CFrame.new(rootPos) * CFrame.Angles(0, camY, 0)
				
				if USE_SMOOTH_ROTATION then
					_, camY = Camera.CFrame:ToOrientation()
					targetCFrame = CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, camY, 0)	
					HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(targetCFrame, math.min(1, dt * ROTATION_SPEED * 2))		
				else
					HumanoidRootPart.CFrame = targetCFrame	
				end	
			else
				Humanoid.AutoRotate = true
			end
		end)
	else
		RunService:UnbindFromRenderStep("ShiftLockRotation")

		controller.StatusService:SetStatus(Character, 
			"ShiftLock", 
			nil
		)

		if Humanoid then
			Humanoid.AutoRotate = true
		end
	end
end

function CameraHandler:IsShiftLockEnabled()
	return shiftLockEnabled
end

function CameraHandler:UpdateCamera(DeltaTime, controller)
	if not (Camera and controller.Character) then 
		return 
	end

	DeltaTime = DeltaTime or RunService.RenderStepped:Wait() 

	local totalOffset = CameraHandler.cameraOffsetSpring.Position + shakeSpring.Position
	Camera.CFrame = Camera.CFrame * CFrame.new(totalOffset)
end

return CameraHandler
