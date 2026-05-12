--@ Diving
local DiveComponent = {}

function DiveComponent:Init()
end

function DiveComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsDiving = true }) then return end
	controller.StatusService:SetStatus(Character, "IsDiving", true)
	
	task.delay(5, function()
		if controller.StatusService:CheckStatuses(Character, { IsDiving = true }) then
			controller.StatusService:RemoveStatus(Character, "IsDiving")
		end
	end)
end

function DiveComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsDiving = true }) then
		controller.StatusService:RemoveStatus(Character, "IsDiving")
	end
end

return DiveComponent
