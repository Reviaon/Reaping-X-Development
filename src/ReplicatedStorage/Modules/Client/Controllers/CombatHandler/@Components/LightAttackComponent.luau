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
	 
	local weaponId = combatState.ActiveWeapon or 
		controller.CombatConfig:ResolveWeaponId(controller)

	if weaponId == "Unarmed" then
		return
	end

	local comboIndex = (combatState.ComboIndex % 10)

	if comboIndex == 0 then
		comboIndex = 1
	end
   

	local animationName = string.format("%s%d", weaponId, comboIndex)

	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end

	_currentTrack = controller.AnimatorService:PlayTrack(Character, animationName, {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.1,
	})

	controller.StatusService:SetStatus(Character, "IsAttacking", true, 0.2)
end

function LightAttackComponent:Deactivate(_controller, _combatState)
	if _currentTrack then
		_currentTrack:Stop(0.15)
		_currentTrack = nil
	end
end

return LightAttackComponent