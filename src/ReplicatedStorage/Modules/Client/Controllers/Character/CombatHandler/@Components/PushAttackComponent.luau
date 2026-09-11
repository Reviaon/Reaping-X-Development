--@ Heavy Attack Component
local PushComponent = {}

function PushComponent:Init(_controller)
end

function PushComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then return false end

	if controller.StatusService:CheckStatuses(Character, { IsStunned = true }) then
		return false
	end

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