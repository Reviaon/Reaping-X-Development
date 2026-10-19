--@ Lean
local Config = require("@self/Config")

local LeanComponent = {}

local SCOPE = "Lean"

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function resetMotion(state)
	state.lastPosition = state.root.Position
	state.velocity = Vector3.zero
	state.accel = Vector3.zero
end

local function resolve(controller, state): boolean
	local root = controller.HumanoidRootPart
	local humanoid = controller.Humanoid
	local joint = root and root:FindFirstChild(Config.Joint)

	if not (humanoid and joint and joint:IsA("Motor6D")) then
		return false
	end

	state.root = root
	state.humanoid = humanoid
	state.joint = joint
	state.rest = joint.C0
	state.pitch = 0
	state.side = 0
	state.rested = true
	resetMotion(state)

	return true
end

local function heldUpright(controller, state): boolean
	local humanoid = state.humanoid

	if humanoid.Sit or humanoid.Health <= 0 or state.root.Anchored then
		return true
	end

	if Config.UprightDuringImpulse then
		local impulse = controller.PhysicsService.GetImpulse(state.root)

		if impulse and impulse.Enabled then
			return true
		end
	end

	return controller.StatusService:CheckStatuses(controller.Character, Config.UprightStatuses)
end

function LeanComponent:Update(controller, dt: number)
	if not controller or not controller.Character then return end

	local state = controller:Scope(SCOPE)

	if not state.joint and not resolve(controller, state) then return end

	local joint, root = state.joint, state.root
	if not joint.Parent or not root.Parent then return end

	local position = root.Position
	local travelled = (position - state.lastPosition) * Vector3.new(1, 0, 1)
	state.lastPosition = position

	if travelled.Magnitude > Config.TeleportDistance then
		resetMotion(state)
		travelled = Vector3.zero
	end

	local step = math.max(dt, 1e-4)
	local velocity = travelled / step

	state.accel = state.accel:Lerp((velocity - state.velocity) / step, 1 - math.exp(-Config.AccelRate * dt))
	state.velocity = velocity

	local pitchTarget, sideTarget = 0, 0

	if not heldUpright(controller, state) then
		local frame = root.CFrame
		local heading = frame:VectorToObjectSpace(velocity) / Config.FullSpeed
		local push = frame:VectorToObjectSpace(state.accel) / Config.FullAccel
		local ahead = math.clamp(-push.Z, -1, 1)

		pitchTarget = math.clamp(heading.Z, 0, 1) * Config.Back - math.clamp(-heading.Z, 0, 1) * Config.Forward
		pitchTarget = math.clamp(
			pitchTarget - ahead * (ahead > 0 and Config.Forward or Config.Back),
			-Config.Forward,
			Config.Back
		)
		sideTarget = math.clamp(
			-(math.clamp(heading.X, -1, 1) + math.clamp(push.X, -1, 1)) * Config.Side,
			-Config.Side,
			Config.Side
		)
	end

	state.pitch = approach(state.pitch, pitchTarget, Config.LeanRate, dt)
	state.side = approach(state.side, sideTarget, Config.LeanRate, dt)

	local settled = pitchTarget == 0
		and sideTarget == 0
		and math.abs(state.pitch) < Config.RestEpsilon
		and math.abs(state.side) < Config.RestEpsilon

	if settled then
		if not state.rested then
			state.rested = true
			state.pitch = 0
			state.side = 0
			joint.C0 = state.rest
		end

		return
	end

	state.rested = false
	joint.C0 = CFrame.Angles(state.pitch, 0, state.side) * state.rest
end

function LeanComponent:Init(controller)
	if not controller.Character then return end

	LeanComponent.Reset(controller)
	resolve(controller, controller:Scope(SCOPE))
end

function LeanComponent.Reset(controller)
	if not controller then return end

	local state = controller:Scope(SCOPE)
	local joint = state.joint

	if joint and joint.Parent then
		joint.C0 = state.rest
	end

	state.joint = nil
	state.root = nil
	state.humanoid = nil
	state.rest = nil
end

return LeanComponent
