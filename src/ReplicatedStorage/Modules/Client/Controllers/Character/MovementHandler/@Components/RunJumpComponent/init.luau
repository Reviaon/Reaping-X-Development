--@ Run jump
local RunService = game:GetService("RunService")

local Config = require("@self/Config")
local RunJumpComponent = {}

local SCOPE = "RunJump"

local AIRBORNE = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local function stopLift(state)
	if state.step then
		state.step:Disconnect()
		state.step = nil
	end

	if state.lift then
		state.lift:Destroy()
		state.lift = nil
	end
end

local function liftFor(root: BasePart, scale: number): Vector3
	return Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - scale), 0)
end

local function startLift(controller, state)
	stopLift(state)

	local character = controller.Character
	local humanoid = controller.Humanoid
	local root = controller.HumanoidRootPart

	local attachment = controller.PhysicsService.ImpulseAttachment(root)
	if not attachment then return end

	local lift = Instance.new("VectorForce")
	lift.Name = Config.ForceName
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = liftFor(root, Config.RiseGravity)
	lift.Parent = root

	state.lift = lift

	local began = os.clock()

	state.step = RunService.Heartbeat:Connect(function()
		if not root.Parent
			or not AIRBORNE[humanoid:GetState()]
			or os.clock() - began > Config.MaxAirtime
			or controller.StatusService:CheckStatuses(character, Config.CancelOn)
		then
			stopLift(state)
			return
		end

		local rising = root.AssemblyLinearVelocity.Y > 0
		lift.Force = liftFor(root, rising and Config.RiseGravity or Config.FallGravity)
	end)
end

function RunJumpComponent:Init(controller)
	if not controller.Character then return end

	RunJumpComponent.Reset(controller)

	local state = controller:Scope(SCOPE)
	local character = controller.Character
	local humanoid = controller.Humanoid

	state.trove = controller.Trove.new()

	state.trove:Add(humanoid.StateChanged:Connect(function(_, new)
		if new ~= Enum.HumanoidStateType.Jumping then return end
		if not controller.StatusService:CheckStatuses(character, { IsSprinting = true }) then return end

		startLift(controller, state)
	end))

	state.trove:Add(humanoid.Died:Connect(function()
		RunJumpComponent.Reset(controller)
	end))
end

function RunJumpComponent.Reset(controller)
	if not controller then return end

	local state = controller:Scope(SCOPE)

	stopLift(state)

	if state.trove then
		state.trove:Clean()
		state.trove = nil
	end
end

return RunJumpComponent
