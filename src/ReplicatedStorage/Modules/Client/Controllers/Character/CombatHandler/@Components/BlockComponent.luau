--@ Block Component
local BlockComponent = {}

local BLOCK = "Block"

function BlockComponent:Init(_controller)
end

function BlockComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, { IsAttacking = true, IsCrouching = true }) then
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

	controller.AttackService:SwapTrack(controller, BLOCK, Character, "UniversalBlock", {
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

	controller.AttackService:StopTrack(controller, BLOCK, 0.15)

	if controller.StatusService:CheckStatuses(Character, { IsBlocking = true }) then
		controller.StatusService:RemoveStatus(Character, "IsBlocking")
	end
end

return BlockComponent