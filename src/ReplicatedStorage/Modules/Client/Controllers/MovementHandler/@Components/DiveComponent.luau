--@ Diving
local DiveComponent = {}

function DiveComponent:Init()
end

function DiveComponent:Activate(controller)
	local _character = controller.Character

	if not _character then 
		return 
	end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then 
		return 
	end

	controller.StatusService:SetStatus(_character, "IsDiving", true)
	controller.StatusService:SetStatus(_character, "NoRotate", true, 1)

	local _divetracks = {
		["W"] = controller.AnimatorService:GetTrack(_character, "DiveForward"),
		["A"] = controller.AnimatorService:GetTrack(_character, "DiveLeft"),
		["S"] = controller.AnimatorService:GetTrack(_character, "DiveForward"),
		["D"] = controller.AnimatorService:GetTrack(_character, "DiveRight"),
	}

	local _IsShiftlock = controller.StatusService:CheckStatuses(_character, { ShiftLock = true })
	local _heldbind = controller.InputHandler:AreKeysDown({"W","A","S","D"})
	
	warn("Dive Activated", _IsShiftlock, _heldbind)

	if _heldbind and _divetracks[_heldbind] then
		_divetracks.Priority = Enum.AnimationPriority.Action4
		_divetracks[_heldbind]:Play()
	else
		_divetracks.Priority = Enum.AnimationPriority.Action4
		_divetracks["W"]:Play()
	end

	DiveComponent:Deactivate(controller)
end	

function DiveComponent:Deactivate(controller)
	local _character = controller.Character
	if not _character then return end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then
		controller.StatusService:RemoveStatus(_character, "IsDiving")
	end
end

return DiveComponent
