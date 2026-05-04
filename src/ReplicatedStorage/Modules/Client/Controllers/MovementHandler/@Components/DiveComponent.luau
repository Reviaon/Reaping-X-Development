--@ Diving
local DiveComponent = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local AnimatorService = GlobalFunctions.AnimatorService
local StatusService   = GlobalFunctions.StatusService

function DiveComponent:Init()
end

function DiveComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	if StatusService:CheckStatuses(Character, { IsDiving = true }) then return end
	StatusService:SetStatus(Character, "IsDiving", true)
end

function DiveComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if StatusService:CheckStatuses(Character, { IsDiving = true }) then
		StatusService:RemoveStatus(Character, "IsDiving")
	end
end

return DiveComponent
