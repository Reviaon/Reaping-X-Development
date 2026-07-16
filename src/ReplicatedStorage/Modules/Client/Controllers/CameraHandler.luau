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

--@ Dynamic camera offset (drift) — tune to taste.
local ORIGIN_FOLLOW_SPEED = 10 --@ how fast the origin part catches up to the torso (lower = more drift)
local DRIFT_STRENGTH = 0.4     --@ fraction of the origin's lag applied as camera drift
local DRIFT_MAX = 2            --@ max drift magnitude, in studs

local INFLUENCE_FLOOR = 0.2
local INFLUENCE_BLEND = 6
local _influenceLevel = INFLUENCE_FLOOR

local SUBJECT_HEIGHT_OFFSET = 1.5 --@ Torso subject sits at chest level; raise to the Humanoid subject's default head-level POV

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

local originCache = nil

local function getOriginCache()
	if originCache then
		return originCache
	end

	local template = Instance.new("Part")
	template.Name = "CameraOrigin"
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Transparency = 1
	template.Size = Vector3.new(1, 1, 1)

	originCache = GlobalFunctions.PartCache.new(template, 2)
	template:Destroy()

	return originCache
end

local function getTorso(Character)
	return Character
		and (
			Character:FindFirstChild("Torso")
			or Character:FindFirstChild("UpperTorso")
			or Character:FindFirstChild("HumanoidRootPart")
		)
end

function CameraHandler:CreateCameraObject(controller)
	
	if controller._camera_origin then
		getOriginCache():ReturnPart(controller._camera_origin)
		controller._camera_origin = nil
	end

	local _camera_origin = getOriginCache():GetPart()
	controller._camera_origin = _camera_origin

	local torso = getTorso(controller.Character)

	if torso then
		_camera_origin.CFrame = torso.CFrame
	end

	return _camera_origin
end

function CameraHandler:InitCharacter(controller)
	local Character = controller.Character	

	if not Character then return warn("@CHARACTER FAILED TO LOAD") end

	--@ Tear down any loop/pooled part left over from a previous character.
	CameraHandler:Cleanup(controller)

	local _humanoid = Character:WaitForChild("Humanoid")
	local _trove = controller.Trove.new()
	controller._camera_trove = _trove

	local _mouse = MouseModule.new()

	MOUSE_OBJECT = _mouse
	MOUSE_OBJECT.filterDescendants = {Character, workspace.World.Visuals, workspace.World.Live}

	CameraHandler:ToggleShiftLock(shiftLockEnabled, controller)
	CameraHandler:CreateCameraObject(controller)

	_trove:Add(_humanoid.Died:Connect(function()
		CameraHandler:OnCharacterRemoved(controller)
	end))

	_trove:BindToRenderStep("CameraOriginUpdate", Enum.RenderPriority.Camera.Value - 1, function(DeltaTime: number)
		CameraHandler:UpdateOrigin(DeltaTime, controller)
	end)

	_trove:BindToRenderStep("CameraOffsetUpdate", Enum.RenderPriority.Camera.Value + 2, function(DeltaTime: number)
		CameraHandler:UpdateCamera(DeltaTime, controller)
	end)

	warn("CAMERA HANDLER INITIALIZED", controller.Character)
end


--@ Release the per-character render loop and return the pooled origin part.
function CameraHandler:Cleanup(controller)
	_influenceLevel = INFLUENCE_FLOOR
	controller._camera_world_lag = nil

	if controller._camera_trove then
		controller._camera_trove:Destroy()
		controller._camera_trove = nil
	end

	if controller._camera_origin then
		if Camera and Camera.CameraSubject == controller._camera_origin then
			Camera.CameraSubject = controller.Character and controller.Character:FindFirstChildOfClass("Humanoid")
		end
		getOriginCache():ReturnPart(controller._camera_origin)
		controller._camera_origin = nil
	end
end

function CameraHandler:OnCharacterRemoved(controller)
	CameraHandler:ToggleShiftLock(false, controller)
	CameraHandler:Cleanup(controller)
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

function CameraHandler:UpdateOrigin(DeltaTime, controller)
	local origin = controller._camera_origin
	local Character = controller.Character

	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

	if not (origin and Character and Humanoid) then
		controller._camera_world_lag = Vector3.zero
		return
	end

	local torso = getTorso(Character)
	if not torso then
		controller._camera_world_lag = Vector3.zero
		return
	end

	local status = controller.StatusService
	local torsoFocus = CFrame.new(torso.Position + Vector3.new(0, 2, 0))

	local gated = Humanoid.FloorMaterial ~= Enum.Material.Air
		and (
			status:CheckStatuses(Character, { IsAttacking = true })
			or status:CheckStatuses(Character, { IsCrouching = true })
			or status:CheckStatuses(Character, { DiveDirection = "S" })
		)

	_influenceLevel = _influenceLevel + ((gated and 1 or INFLUENCE_FLOOR) - _influenceLevel) * math.min(1, DeltaTime * INFLUENCE_BLEND)

	origin.CFrame = origin.CFrame:Lerp(torsoFocus, math.min(1, DeltaTime * ORIGIN_FOLLOW_SPEED))

	if Camera and Camera.CameraSubject and Camera.CameraSubject ~= origin then
		Camera.CameraSubject = torso
	end

	controller._camera_world_lag = torsoFocus.Position - origin.Position
end

function CameraHandler:UpdateCamera(DeltaTime, controller)
	if not (Camera and controller.Character) then
		return
	end

	local drift = Vector3.zero
	local worldLag = controller._camera_world_lag

	if worldLag then
		local localLag = Camera.CFrame:VectorToObjectSpace(worldLag) * DRIFT_STRENGTH * _influenceLevel
		drift = Vector3.new(localLag.X, localLag.Y, 0)

		if drift.Magnitude > DRIFT_MAX then
			drift = drift.Unit * DRIFT_MAX
		end
	end

	local totalOffset = CameraHandler.cameraOffsetSpring.Position + shakeSpring.Position + drift
	Camera.CFrame = Camera.CFrame * CFrame.new(totalOffset) + Vector3.new(0, SUBJECT_HEIGHT_OFFSET, 0)
end

return CameraHandler
