local TiltController = {}

local Jloader = require(game.ReplicatedStorage.JLoader)
local CameraHandler = Jloader.GetHandler("CameraHandler")

local GlobalFunctions = Jloader.GlobalFunctions
local MouseModule = GlobalFunctions.MouseModule

local CFNew, CFAng, CFtoObjectSpace = CFrame.new, CFrame.Angles, CFrame.new( ).toObjectSpace
local asin, pi, hpi = math.asin, math.pi, math.pi / 2

function TiltController:Update(dt: number)
	local BodyMover = self.RootPart:FindFirstChildWhichIsA("BodyMover")
	local Force = self.RootPart.Velocity * Vector3.new(1, 0, 1)

	local Direction, xAxis, zAxis = Force.Unit, 0, 0

	if Force.Magnitude > 2
		and not BodyMover
		and not self.RootPart.Anchored 
		and self.Humanoid.WalkSpeed > 0
	then
		Direction = Force.Unit
		xAxis = self.RootPart.CFrame.LookVector:Dot(Direction)
		zAxis = self.RootPart.CFrame.RightVector:Dot(Direction)
	end

	local LerpSpeed = 0.1 * 60 * dt	
		
	self.RootJoint.C0 = self.RootJoint.C0:Lerp(self.RootJointC0 * CFrame.Angles(math.rad(xAxis * 5), math.rad(-zAxis * 5), 0), LerpSpeed)
	self.LeftHipJoint.C0 = self.LeftHipJoint.C0:Lerp(self.LeftHipJointC0 * CFrame.Angles(math.rad(zAxis * 4), 0, 0), LerpSpeed)
	self.RightHipJoint.C0 = self.RightHipJoint.C0:Lerp(self.RightHipJointC0 * CFrame.Angles(math.rad(-zAxis * 4), 0, 0), LerpSpeed)
		
	self.RightShoulderJoint.C0 = self.RightShoulderJoint.C0:Lerp(self.RightShoulderJointC0, LerpSpeed)
	self.LeftShoulderJoint.C0 = self.LeftShoulderJoint.C0:Lerp(self.LeftShoulderJointC0, LerpSpeed)

	if self.NeckJoint then
		self.NeckJoint.C0 = self.NeckJoint.C0:Lerp(self.NeckJointC0, LerpSpeed)
	end
end

function TiltController:Init(Character: Model)
	local Player = game.Players:GetPlayerFromCharacter(Character)
	
	self.Mouse = Player:GetMouse()
	self.Camera = workspace.CurrentCamera
	
	self.Character = Character
	self.RootPart = Character:WaitForChild("HumanoidRootPart")
	self.Torso = Character:WaitForChild("Torso")
	self.Humanoid = Character:WaitForChild("Humanoid")

	self.RootJoint = self.RootPart:WaitForChild("RootJoint")
	self.LeftHipJoint = self.Torso:WaitForChild("Left Hip")
	self.RightHipJoint = self.Torso:WaitForChild("Right Hip")

	self.LeftShoulderJoint = self.Torso:WaitForChild("Left Shoulder")
	self.RightShoulderJoint = self.Torso:WaitForChild("Right Shoulder")
	
	self.NeckJoint = self.Torso:WaitForChild("Neck")
	self.YNeckOffset = self.NeckJoint.C0.Y

	self.RootJointC0 = self.RootJoint.C0
	self.LeftHipJointC0 = self.LeftHipJoint.C0
	self.RightHipJointC0 = self.RightHipJoint.C0
	
	self.LeftShoulderJointC0 = self.LeftShoulderJoint.C0
	self.RightShoulderJointC0 = self.RightShoulderJoint.C0
	self.NeckJointC0 = self.NeckJoint.C0
	
	self.Mouse = MouseModule.new()
	self.Mouse.filterDescendants = {self.Character, 
		workspace.World.Visuals, 
		workspace.World.Live, 
		workspace.World.Map
	}
	
	self.MaxArmTilt = 8 -- How far up the arms can tilt (positive)
	self.MinArmTilt = -8 -- How far down the arms can tilt (negative)
end

return TiltController