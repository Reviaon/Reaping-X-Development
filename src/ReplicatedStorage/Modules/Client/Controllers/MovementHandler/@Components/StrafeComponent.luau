--@ Strafing
local StrafeComponent = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local CameraHandler = Jloader.GetHandler("CameraHandler")
local AnimatorService = GlobalFunctions.AnimatorService
local Trove = GlobalFunctions.Trove

local DOT_THRESHOLD = 0.9

--@ Animation sets keyed by controller state flag.
local STATE_ANIMATIONS = {
	{ state = "IsCrouching", anims = {
		Forward = "CrouchForwardWalk",
		Backward = "CrouchBackwardWalk",
		Left = "CrouchLeftWalk",
		Right = "CrouchRightWalk",
	}},
	{ state = "Default", anims = {
		Forward = "WalkForward",
		Backward = "WalkBackward",
		Left = "WalkLeft",
		Right  = "WalkRight",
	}},
}

local function resolveAnimSet(controller)
	for _, entry in ipairs(STATE_ANIMATIONS) do
		if entry.state == "Default" then
			return entry.anims
		end
		if controller[entry.state] == true then
			return entry.anims
		end
	end
end

local _trove = nil
local _currentTrack = nil
local _currentAnim = nil

local function playAnimation(controller, animName: string)
	if _currentAnim == animName then return end

	if _currentTrack then
		_currentTrack:Stop(0.3)
	end

	_currentTrack = AnimatorService:PlayTrack(controller.Character, animName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.3,
	})

	_currentAnim = animName
end

local function stopAnimation()
	if _currentTrack then
		_currentTrack:Stop(0.3)
		_currentTrack = nil
		_currentAnim = nil
	end
end

local function update(controller)
	local Humanoid         = controller.Humanoid
	local HumanoidRootPart = controller.HumanoidRootPart
	if not Humanoid or not HumanoidRootPart then return end

	local MoveDirection = Humanoid.MoveDirection

	if not CameraHandler:IsShiftLockEnabled() then
		stopAnimation()
		return
	end

	if MoveDirection.Magnitude <= 0 then
		stopAnimation()
		return
	end

	local MoveDirectionLocal = HumanoidRootPart.CFrame:VectorToObjectSpace(MoveDirection)	

	local anims = resolveAnimSet(controller)

	if     MoveDirectionLocal:Dot(Vector3.new( 1, 0, -1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Forward)
	elseif MoveDirectionLocal:Dot(Vector3.new( 1, 0,  1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Backward)
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0,  1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Backward)
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0, -1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Forward)
	elseif MoveDirectionLocal:Dot(Vector3.new( 0, 0, -1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Forward)
	elseif MoveDirectionLocal:Dot(Vector3.new( 1, 0,  0).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Right)
	elseif MoveDirectionLocal:Dot(Vector3.new( 0, 0,  1).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Backward)
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0,  0).Unit) > DOT_THRESHOLD then playAnimation(controller, anims.Left)
	end
end

function StrafeComponent:Init(controller)
	if not controller.Character then return end

	StrafeComponent.Reset()

	_trove = Trove.new()

	_trove:Add(RunService.RenderStepped:Connect(function()
		update(controller)
	end))

	_trove:Add(controller.Humanoid.Died:Connect(function()
		StrafeComponent.Reset()
	end))

	update(controller)
end

function StrafeComponent.Reset()
	stopAnimation()

	if _trove then
		_trove:Clean()
		_trove = nil
	end
end

return StrafeComponent
