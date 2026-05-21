--@ Heavy Attack Component
local PushComponent = {}

local _currentTrack = nil

function PushComponent:Init(_controller)
end

function PushComponent:CanActivate(_controller, _combatState): boolean
	return true
end

function PushComponent:Activate(controller, _combatState)
	local Character = controller.Character
	if not Character then return end

	controller.StatusService:SetStatus(Character, "IsAttacking", true, 0.45)
end

function PushComponent:Deactivate(_controller, _combatState)
end

return PushComponent