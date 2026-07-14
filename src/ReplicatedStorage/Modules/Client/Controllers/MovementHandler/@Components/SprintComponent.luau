--@ Sprinting
local SprintComponent = {}

local RunService = game:GetService("RunService")

local _trove = nil
local _sprintTrack  = nil

local function stopSprint(controller)
	if _sprintTrack then
		_sprintTrack:Stop(0.3)
		_sprintTrack = nil
		controller.SprintTrack = nil
	end
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

	controller.StatusService:SetStatus(Character, "IsSprinting", true)

	_sprintTrack = controller.AnimatorService:PlayTrack(Character, "UniversalSprintAnim", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
	})

	_trove = controller.Trove.new()

	_trove:Add(RunService.Heartbeat:Connect(function()
		if not controller.StatusService:CheckStatuses(Character, { IsSprinting = true }) then
			if _trove then
				_trove:Clean()
				_trove = nil
			end
			return
		end

		if Humanoid.MoveDirection.Magnitude <= 0 then
			if _sprintTrack and _sprintTrack.IsPlaying then
				_sprintTrack:Stop(0.3)
			end
		else
			if _sprintTrack and not _sprintTrack.IsPlaying
				and not (Humanoid.FloorMaterial == Enum.Material.Air
				or Humanoid:GetState() == Enum.HumanoidStateType.Jumping) then
				_sprintTrack:Play()
			end
		end
	end))

	controller.SprintTrack = _sprintTrack
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
	if controller then
		stopSprint(controller)
	end

	if _trove then
		_trove:Clean()
		_trove = nil
	end
end

return SprintComponent
