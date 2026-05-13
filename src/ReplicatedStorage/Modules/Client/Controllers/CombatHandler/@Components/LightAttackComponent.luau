--@ Light Attack Component
local LightAttackComponent = {}

local _currentTrack = nil

function LightAttackComponent:Init(_controller)
end

function LightAttackComponent:CanActivate(_controller, _combatState): boolean
	return true
end

function LightAttackComponent:Activate(controller, combatState)
	local Character = controller.Character
	if not Character then return end

	--@ Build animation name from combo index: Light1, Light2, Light3, etc.
	local comboIndex = (combatState.ComboIndex % 10)
	if comboIndex == 0 then comboIndex = 1 end
	local animationName = "Light" .. comboIndex

	--@ Stop previous track if still playing
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	--@ Play the combo-appropriate attack animation
	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
	})

	--@ Attack lock window scaled to animation timing
	controller.StatusService:SetStatus(Character, "IsAttacking", true, 0.2)
end

function LightAttackComponent:Deactivate(_controller, _combatState)
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return LightAttackComponent