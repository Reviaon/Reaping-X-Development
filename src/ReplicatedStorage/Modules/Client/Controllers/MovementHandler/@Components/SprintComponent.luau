--@ Sprinting
local SprintComponent = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local AnimatorService = GlobalFunctions.AnimatorService
local StatusService = GlobalFunctions.StatusService
local Trove = GlobalFunctions.Trove

--@ Module-local state
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

	if StatusService:CheckStatuses(Character, { Sprinting = true }) then return end

	StatusService:SetStatus(Character, "Sprinting", true)

	_sprintTrack = AnimatorService:PlayTrack(Character, "SprintAnim", {
		Speed    = 1,
		Priority = Enum.AnimationPriority.Movement,
		FadeTime = 0.2,
    })

	controller.SprintTrack = _sprintTrack
end

function SprintComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if StatusService:CheckStatuses(Character, { Sprinting = true }) then
		StatusService:RemoveStatus(Character, "Sprinting")
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
