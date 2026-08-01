--@ Block Component
local BlockComponent = {}

local _blockTrack = nil

function BlockComponent:Init(_controller)
end

function BlockComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, { IsAttacking = true }) then
		return false
	end

	return true
end

function BlockComponent:Activate(controller, combatState)
	if not BlockComponent:CanActivate(controller, combatState) then
		return
	end

	local Character = controller.Character
	if not Character then return end

	if _blockTrack then
		_blockTrack:Stop(0.1)
		_blockTrack = nil
	end

	_blockTrack = controller.AnimatorService:PlayTrack(Character, "UniversalBlock", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.15,
		Loop = true,
	})

	controller.StatusService:SetStatus(Character, "IsBlocking", true)
end

function BlockComponent:Deactivate(controller, _combatState)
	local Character = controller.Character
	if not Character then return end

	if _blockTrack then
		_blockTrack:Stop(0.15)
		_blockTrack = nil
	end

	if controller.StatusService:CheckStatuses(Character, { IsBlocking = true }) then
		controller.StatusService:RemoveStatus(Character, "IsBlocking")
	end
end

return BlockComponent