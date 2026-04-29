--@ Crouching
local CrouchComponent = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local AnimatorService = GlobalFunctions.AnimatorService
local StatusService  = GlobalFunctions.StatusService

function CrouchComponent:Init()
end


function CrouchComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	--@ Guard: already crouching
	if StatusService:CheckStatuses(Character, { IsCrouching = true }) then return end

	StatusService:SetStatus(Character, "IsCrouching", true)

	local crouch_track = AnimatorService:PlayTrack(Character, "CrouchIdle", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Idle,
		FadeTime = 0.3,
	})

    controller.CrouchIdle = crouch_track
end

function CrouchComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if StatusService:CheckStatuses(Character, { IsCrouching = true }) then
		StatusService:RemoveStatus(Character, "IsCrouching")
	end

	local crouch_track = controller.CrouchIdle

	if crouch_track then
		crouch_track:Stop(0.2)

		controller.CrouchIdle = nil
	end
end

return CrouchComponent
