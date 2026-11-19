--@ Crouching
local Jloader = require("@game/ReplicatedStorage/JLoader")

local CrouchComponent = {}

local stealth = nil

local function report(sneaking: boolean)
	stealth = stealth or Jloader.GetService("StealthService")

	if stealth then
		stealth.ReportSneak:Fire(sneaking)
	end
end

function CrouchComponent:Init()
end

function CrouchComponent:CanActivate(controller)
	local Character = controller.Character
	if not Character then return false end

	if controller.StatusService:CheckStatuses(Character, { IsCrouching = true, IsBlocking = true })
		or controller.StatusService:IsHitYielded(Character)
		or controller.StatusService:IsActionLocked(Character)
	then
		return false
	end

	return true
end

function CrouchComponent:Activate(controller)
	local Character = controller.Character
	if not Character then return end

	if not CrouchComponent:CanActivate(controller) then return end

	controller.StatusService:SetStatus(Character, "IsCrouching", true)
	report(true)

	local track = controller.AnimatorService:PlayTrack(Character, "CrouchIdle", {
		Speed = 1,
		Priority = Enum.AnimationPriority.Idle,
		FadeTime = 0.3,
	})

	controller.CrouchIdle = track
end

function CrouchComponent:Deactivate(controller)
	local Character = controller.Character
	if not Character then return end

	if controller.StatusService:CheckStatuses(Character, { IsCrouching = true }) then
		controller.StatusService:RemoveStatus(Character, "IsCrouching")
		report(false)
	end

	local track = controller.CrouchIdle
	if track then
		track:Stop(0.2)
		controller.CrouchIdle = nil
	end
end

return CrouchComponent
