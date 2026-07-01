--@ Crouching
local CrouchComponent = {}

function CrouchComponent:Init()
end

function CrouchComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsCrouching = true }) then return end

	controller.StatusService:SetStatus(Character, "IsCrouching", true)

	local track = controller.AnimatorService:PlayTrack(Character, "CrouchIdle", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Idle,
		FadeTime = 0.3,
	})

	controller.CrouchIdle = track
end

function CrouchComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsCrouching = true }) then
		controller.StatusService:RemoveStatus(Character, "IsCrouching")
	end

	local track = controller.CrouchIdle
	if track then
		track:Stop(0.2)
		controller.CrouchIdle = nil
	end
end

return CrouchComponent
