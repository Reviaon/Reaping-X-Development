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
	local Character = controller:Get("Character")
	if not Character then return end

	--@ Guard: already crouching
	if StatusService:CheckStatuses(Character, { Crouching = true }) then return end

	StatusService:SetStatus(Character, "Crouching", true)

	local track = AnimatorService:PlayTrack(Character, "CrouchIdle", {
		Speed    = 1,
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.3,
	})
	controller:Set("CrouchIdle", track)
end

function CrouchComponent:Deactivate(controller)
	local Character = controller:Get("Character")
	if not Character then return end

	if StatusService:CheckStatuses(Character, { Crouching = true }) then
		StatusService:RemoveStatus(Character, "Crouching")
	end


	local track = controller:Get("CrouchIdle")

	if track then
		track:Stop(0.2)
		controller:Remove("CrouchIdle")
	end
end

return CrouchComponent
