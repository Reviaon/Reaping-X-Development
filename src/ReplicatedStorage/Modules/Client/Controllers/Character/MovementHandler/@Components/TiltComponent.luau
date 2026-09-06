local TiltComponent = {}

local SCOPE = "Tilt"

local JOINTS = {
	{ key = "root", host = "RootPart", name = "RootJoint" },
	{ key = "leftHip", host = "Torso", name = "Left Hip" },
	{ key = "rightHip", host = "Torso", name = "Right Hip" },
	{ key = "leftShoulder", host = "Torso", name = "Left Shoulder" },
	{ key = "rightShoulder", host = "Torso", name = "Right Shoulder" },
	{ key = "neck", host = "Torso", name = "Neck" },
}

function TiltComponent:Update(controller, dt: number)
	if not controller then return end

	local state = controller:Scope(SCOPE)
	local joints = state.joints

	if not joints or not state.rootPart or not state.humanoid then return end
	if not state.rootPart.Parent then return end

	local Impulse = controller.PhysicsService.GetImpulse(state.rootPart)
	local Force = state.rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

	local xAxis, zAxis = 0, 0

	if Force.Magnitude > 2
		and not Impulse
		and not state.rootPart.Anchored
		and state.humanoid.WalkSpeed > 0
	then
		local Direction = Force.Unit
		xAxis = state.rootPart.CFrame.LookVector:Dot(Direction)
		zAxis = state.rootPart.CFrame.RightVector:Dot(Direction)
	end

	local LerpSpeed = 0.1 * 60 * dt

	joints.root.instance.C0 = joints.root.instance.C0:Lerp(
		joints.root.rest * CFrame.Angles(math.rad(xAxis * 5), math.rad(-zAxis * 5), 0), LerpSpeed)

	joints.leftHip.instance.C0 = joints.leftHip.instance.C0:Lerp(
		joints.leftHip.rest * CFrame.Angles(math.rad(zAxis * 4), 0, 0), LerpSpeed)

	joints.rightHip.instance.C0 = joints.rightHip.instance.C0:Lerp(
		joints.rightHip.rest * CFrame.Angles(math.rad(-zAxis * 4), 0, 0), LerpSpeed)

	joints.rightShoulder.instance.C0 = joints.rightShoulder.instance.C0:Lerp(joints.rightShoulder.rest, LerpSpeed)
	joints.leftShoulder.instance.C0 = joints.leftShoulder.instance.C0:Lerp(joints.leftShoulder.rest, LerpSpeed)

	if joints.neck then
		joints.neck.instance.C0 = joints.neck.instance.C0:Lerp(joints.neck.rest, LerpSpeed)
	end
end

function TiltComponent:Init(controller)
	local Character = controller.Character
	if not Character then return end

	local hosts = {
		RootPart = Character:WaitForChild("HumanoidRootPart"),
		Torso = Character:WaitForChild("Torso"),
	}

	local state = controller:Scope(SCOPE)
	state.rootPart = hosts.RootPart
	state.humanoid = Character:WaitForChild("Humanoid")

	local joints = {}

	for _, entry in JOINTS do
		local instance = hosts[entry.host]:WaitForChild(entry.name)
		joints[entry.key] = { instance = instance, rest = instance.C0 }
	end

	state.joints = joints
end

function TiltComponent.Reset(controller)
	if not controller then return end

	local state = controller:Scope(SCOPE)
	state.rootPart = nil
	state.humanoid = nil
	state.joints = nil
end

return TiltComponent
