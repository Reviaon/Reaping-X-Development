--@ Strafing
local DirectionalMovement = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserinputService = game:GetService("UserInputService")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local CameraHandler = Jloader.GetHandler("CameraHandler")
local AnimatorService = GlobalFunctions.AnimatorService

local DirectionalSettings = {
	DefaultLerpAlpha = 0.145,
	dotThreshold = 0.9,

	CurrentAnimation = nil,
	CurrentAnimationName = nil,

	Trove = GlobalFunctions.Trove.new(),
}

function DirectionalMovement:PlayAnimation(animationName)
	if DirectionalSettings.CurrentAnimationName == animationName then
		return
	end

	if DirectionalSettings.CurrentAnimation then
		DirectionalSettings.CurrentAnimation:Stop()
	end

	DirectionalSettings.CurrentAnimation = GlobalFunctions.AnimatorService:PlayTrack(self.Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.3
	})

	DirectionalSettings.CurrentAnimationName = animationName
end

function DirectionalMovement:StopAnimation()
	if DirectionalSettings.CurrentAnimation then
		DirectionalSettings.CurrentAnimation:Stop(0.3)
		
		DirectionalSettings.CurrentAnimation = nil
		DirectionalSettings.CurrentAnimationName = nil
	end
end

function DirectionalMovement:CancelWalkAnim()
	local Animator = self.Animator
	
	if Animator then
		for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
			if Track.Name == "WalkAnim" then
				Track:Stop()
			end
		end
	end
end

function DirectionalMovement:Update()
	local MoveDirection = self.Humanoid.MoveDirection

	if not CameraHandler:IsShiftLockEnabled() then
		self:StopAnimation()
		return
	end

	if MoveDirection.Magnitude <= 0 then
		self:StopAnimation()
		return
	end

	local MoveDirectionLocal = self.HumanoidRootPart.CFrame:VectorToObjectSpace(MoveDirection)

	if MoveDirectionLocal:Dot(Vector3.new(1, 0, -1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkForward")
	elseif MoveDirectionLocal:Dot(Vector3.new(1, 0, 1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkBackward")
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0, 1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkBackward")
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0, -1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkForward")
	elseif MoveDirectionLocal:Dot(Vector3.new(0, 0, -1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkForward")
	elseif MoveDirectionLocal:Dot(Vector3.new(1, 0, 0).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkRight")
	elseif MoveDirectionLocal:Dot(Vector3.new(0, 0, 1).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkBackward")
	elseif MoveDirectionLocal:Dot(Vector3.new(-1, 0, 0).Unit) > DirectionalSettings.dotThreshold then
		self:PlayAnimation("WalkLeft")
	end
end

function DirectionalMovement:Init(Character)
	if not Character then return end
		
	self.Character = Character
	self.Humanoid = Character:WaitForChild("Humanoid")
	self.Animator = self.Humanoid:WaitForChild("Animator")
	self.HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

	
	DirectionalSettings.Trove:Add(RunService.RenderStepped:Connect(function()
		self:Update()
	end))
	
	DirectionalSettings.Trove:Add(self.Humanoid.Died:Connect(function()
		self:StopAnimation()
		DirectionalSettings.Trove:Clean()
	end))

	self:Update()
end

function DirectionalMovement.Reset()
	DirectionalSettings.Trove:Clean()
end

return DirectionalMovement
