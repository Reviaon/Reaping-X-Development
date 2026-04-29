--@ Tilting
local TiltComponent = {}

local Players = game:GetService("Players")

local _rootPart = nil
local _humanoid = nil

local _rootJoint = nil
local _leftHipJoint = nil
local _rightHipJoint = nil
local _leftShoulderJoint = nil
local _rightShoulderJoint = nil
local _neckJoint  = nil

local _rootJointC0 = nil
local _leftHipJointC0 = nil
local _rightHipJointC0 = nil
local _leftShoulderJointC0 = nil
local _rightShoulderJointC0 = nil
local _neckJointC0 = nil

function TiltComponent:Update(dt: number)
	if not _rootPart or not _humanoid then return end

	local BodyMover = _rootPart:FindFirstChildWhichIsA("BodyMover")
	local Force = _rootPart.Velocity * Vector3.new(1, 0, 1)

	local xAxis, zAxis = 0, 0

	if Force.Magnitude > 2
		and not BodyMover
		and not _rootPart.Anchored
		and _humanoid.WalkSpeed > 0
	then
		local Direction = Force.Unit
		xAxis = _rootPart.CFrame.LookVector:Dot(Direction)
		zAxis = _rootPart.CFrame.RightVector:Dot(Direction)
	end

	local LerpSpeed = 0.1 * 60 * dt

	_rootJoint.C0  = _rootJoint.C0:Lerp(_rootJointC0 * CFrame.Angles(math.rad(xAxis * 5), math.rad(-zAxis * 5), 0), LerpSpeed)
	_leftHipJoint.C0  = _leftHipJoint.C0:Lerp(_leftHipJointC0 * CFrame.Angles(math.rad(zAxis * 4), 0, 0), LerpSpeed)
	_rightHipJoint.C0 = _rightHipJoint.C0:Lerp(_rightHipJointC0 * CFrame.Angles(math.rad(-zAxis * 4), 0, 0), LerpSpeed)
	_rightShoulderJoint.C0= _rightShoulderJoint.C0:Lerp(_rightShoulderJointC0, LerpSpeed)
	_leftShoulderJoint.C0 = _leftShoulderJoint.C0:Lerp(_leftShoulderJointC0, LerpSpeed)

	if _neckJoint then
		_neckJoint.C0 = _neckJoint.C0:Lerp(_neckJointC0, LerpSpeed)
	end
end

function TiltComponent:Init(controller)
	local Character = controller.Character
	if not Character then return end

	local RootPart = Character:WaitForChild("HumanoidRootPart")
	local Torso = Character:WaitForChild("Torso")
	local Humanoid = Character:WaitForChild("Humanoid")

	_rootPart = RootPart
	_humanoid = Humanoid

	_rootJoint = RootPart:WaitForChild("RootJoint")
	_leftHipJoint = Torso:WaitForChild("Left Hip")
	_rightHipJoint = Torso:WaitForChild("Right Hip")
	_leftShoulderJoint  = Torso:WaitForChild("Left Shoulder")
	_rightShoulderJoint = Torso:WaitForChild("Right Shoulder")
	_neckJoint  = Torso:WaitForChild("Neck")

	_rootJointC0 = _rootJoint.C0
	_leftHipJointC0 = _leftHipJoint.C0
	_rightHipJointC0 = _rightHipJoint.C0
	_leftShoulderJointC0 = _leftShoulderJoint.C0
	_rightShoulderJointC0 = _rightShoulderJoint.C0
	_neckJointC0 = _neckJoint.C0
end

function TiltComponent.Reset()
	_rootPart = nil
	_humanoid = nil
	_rootJoint = nil
	_leftHipJoint = nil
	_rightHipJoint = nil
	_leftShoulderJoint = nil
	_rightShoulderJoint = nil
	_neckJoint = nil
end

return TiltComponent