local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local CameraHandler = Jloader.CreateHandler({Name = script.Name})

--@ Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

--@ Modules
local GlobalFunctions = Jloader.GlobalFunctions
local Spring = GlobalFunctions.Spring
local StatusService = GlobalFunctions.StatusService
local InputHandler = GlobalFunctions.InputHandler
local RaycastService = GlobalFunctions.RaycastService
local MouseModule = GlobalFunctions.MouseModule

--@ Constants
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local SHIFT_LOCK_KEYS = {Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift}
local SHIFT_LOCK_OFFSET = Vector3.new(2, 0, 0)
local LOCK_ICON = ""

local TRANSITION_DAMPER = 1.5
local TRANSITION_IN_SPEED = 60
local TRANSITION_OUT_SPEED = 30

local ROTATION_SPEED = 20
local FACE_MOUSE_SPEED = 15
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

local heldInputs = {}
local inputConnections = {};

local inputActions = {
	Began = {
		[Enum.KeyCode.LeftControl] = {
			canHold = false,
			action = function(Character : Model)
				CameraHandler:ToggleShiftLock(not shiftLockEnabled)
			end,
		} 
	},
	Ended = {

	}
}

function CameraHandler:Init()

	if LocalPlayer.Character then
		self:OnCharacterAdded(LocalPlayer.Character)
	end

	LocalPlayer.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char)
	end)


	LocalPlayer.CharacterRemoving:Connect(function()
		self:OnCharacterRemoved()
	end)

	RunService.RenderStepped:Connect(function(DeltaTime : number)
		self:UpdateCamera(DeltaTime)
	end)

	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections);
end

function CameraHandler:OnCharacterAdded(char)
	
	self.Character = char
	self.Player = Players:GetPlayerFromCharacter(self.Character)
	
	self.Humanoid = char:WaitForChild("Humanoid")
	self.HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
	self.Head = char:WaitForChild("Head")
	
	self.Humanoid.Died:Connect(function()
		self:ToggleShiftLock(false);
	end)
	
	self:ToggleShiftLock(shiftLockEnabled)
	
	self.Mouse = MouseModule.new()
	self.Mouse.filterDescendants = {self.Character, workspace.World.Visuals, workspace.World.Live}
	--self.MouseIcon = CameraHandler.components["MouseIcon"]:Init(self.Player)
	
	self.Debug = false
	self.DebugMode = function(DEBUG_POS : Vector3)
		local DEBUG_PART = Instance.new("Part")
		DEBUG_PART.Shape = Enum.PartType.Ball
		DEBUG_PART.CanCollide = false
		DEBUG_PART.Anchored = true
		DEBUG_PART.Parent = workspace.World.Visuals
		DEBUG_PART.Material = Enum.Material.Neon
		DEBUG_PART.Color = Color3.new(1, 0, 0)
		DEBUG_PART.Transparency = 0.5
		DEBUG_PART.Position = DEBUG_POS

		task.delay(1, function()
			if DEBUG_PART then
				DEBUG_PART:Destroy()
			end
		end)
	end
		
end

function CameraHandler:OnCharacterRemoved()
	self:ToggleShiftLock(false)
end

function CameraHandler:ShakeCamera(power, decay, amplifier)
	shakeSpring.Position += Vector3.new(
		math.random(-power, power) * amplifier,
		math.random(-power, power) * amplifier,
		math.random(-power, power)
	)
	
	shakeSpring.Damper = decay or 0.8
end

function CameraHandler:ToggleShiftLock(state)
	shiftLockEnabled = state
	UserInputService.MouseBehavior = state and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	CameraHandler.cameraOffsetSpring.Speed = state and TRANSITION_IN_SPEED or TRANSITION_OUT_SPEED
	CameraHandler.cameraOffsetSpring.Target = state and SHIFT_LOCK_OFFSET or Vector3.zero

	if state then
		RunService:BindToRenderStep("ShiftLockRotation", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not (self.Character and self.HumanoidRootPart and Camera) then return end
			if not StatusService:CheckStatuses(self.Character, {NoRotate = true}) and not StatusService:CheckStatuses(self.Character, {IsSprinting = true}) then
				self.Humanoid.AutoRotate = false
				
				local rootPos = self.HumanoidRootPart.Position

				local targetCFrame
	
				local _, camY = Camera.CFrame:ToOrientation()
				targetCFrame = CFrame.new(rootPos) * CFrame.Angles(0, camY, 0)
				
				if USE_SMOOTH_ROTATION then
					local _, camY = Camera.CFrame:ToOrientation()
					targetCFrame = CFrame.new(self.HumanoidRootPart.Position) * CFrame.Angles(0, camY, 0)				
				end
	
				self.HumanoidRootPart.CFrame = self.HumanoidRootPart.CFrame:Lerp(targetCFrame, math.min(1, dt * ROTATION_SPEED * 2))
			else
				self.Humanoid.AutoRotate = true
			end
		end)
	else
		RunService:UnbindFromRenderStep("ShiftLockRotation")

		if self.Humanoid then
			self.Humanoid.AutoRotate = true
		end
	end
end

function CameraHandler:IsShiftLockEnabled()
	return shiftLockEnabled
end

function CameraHandler:UpdateCamera(DeltaTime : number)
	if not (Camera and self.Character and self.Head and self.HumanoidRootPart) then return end

	local totalOffset = CameraHandler.cameraOffsetSpring.Position + shakeSpring.Position
	Camera.CFrame = Camera.CFrame * CFrame.new(totalOffset)

	if not shiftLockEnabled then		
		
	end
end

return CameraHandler
