--@ Heavy Attack Component
local HeavyAttackComponent = {}

local _currentTrack = nil

function HeavyAttackComponent:Init(_controller)
end

function HeavyAttackComponent:CanActivate(_controller, _combatState): boolean
	return true
end

function HeavyAttackComponent:Activate(controller, _combatState)
	local Character = controller.Character
	if not Character then return end

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, "Heavy", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
	})

	controller.StatusService:SetStatus(Character, "IsAttacking", true, 0.45)
end

function HeavyAttackComponent:Deactivate(_controller, _combatState)
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return HeavyAttackComponent