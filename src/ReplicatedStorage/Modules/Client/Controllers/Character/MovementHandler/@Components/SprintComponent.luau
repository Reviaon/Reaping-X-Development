local SprintComponent = {}

local RunService = game:GetService("RunService")

local SCOPE = "Sprint"
local YIELD_TO = { IsBlocking = true }
local SUPPRESSED_BY = { ComboLocked = true, IsStunned = true }

local function stopSprint(controller)
	local state = controller:Scope(SCOPE)

	if state.track then
		state.track:Stop(0.3)
		state.track = nil
		controller.SprintTrack = nil
	end
end

function SprintComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then return false end

	if controller.StatusService:IsHitYielded(Character) then
		return false
	end

	return true
end

function SprintComponent:Init(controller)
	if not controller.Character then return end
	SprintComponent.Reset(controller)
end

function SprintComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return end

	if Humanoid.MoveDirection.Magnitude <= 0 then return end

	if controller.StatusService:CheckStatuses(Character, { IsSprinting = true, IsBlocking = true }) then return end
	if controller.StatusService:IsHitYielded(Character) or controller.StatusService:IsActionLocked(Character) then return end

	controller.StatusService:SetStatus(Character, "IsSprinting", true)

	local state = controller:Scope(SCOPE)

	state.track = controller.AnimatorService:GetTrack(Character, "UniversalSprintAnim")
	state.track.Priority = Enum.AnimationPriority.Action

	if not controller.StatusService:CheckStatuses(Character, SUPPRESSED_BY) then
		state.track:Play(0.1)
	end

	state.trove = controller.Trove.new()

	state.trove:Add(RunService.Heartbeat:Connect(function()
		if controller.StatusService:CheckStatuses(Character, YIELD_TO) then
			SprintComponent:Deactivate(controller)
		end

		if not controller.StatusService:CheckStatuses(Character, { IsSprinting = true }) then
			if state.trove then
				state.trove:Clean()
				state.trove = nil
			end
			return
		end

		if Humanoid.MoveDirection.Magnitude <= 0 or controller.StatusService:CheckStatuses(Character, SUPPRESSED_BY) then
			if state.track and state.track.IsPlaying then
				state.track:Stop(0.3)
			end
		else
			if state.track and not state.track.IsPlaying
				and not (Humanoid.FloorMaterial == Enum.Material.Air
				or Humanoid:GetState() == Enum.HumanoidStateType.Jumping) then
				state.track:Play()
			end
		end
	end))

	controller.SprintTrack = state.track
end

function SprintComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsSprinting = true }) then
		controller.StatusService:RemoveStatus(Character, "IsSprinting")
	end

	stopSprint(controller)
end

function SprintComponent.Reset(controller)
	if not controller then return end

	stopSprint(controller)

	local state = controller:Scope(SCOPE)

	if state.trove then
		state.trove:Clean()
		state.trove = nil
	end
end

return SprintComponent
