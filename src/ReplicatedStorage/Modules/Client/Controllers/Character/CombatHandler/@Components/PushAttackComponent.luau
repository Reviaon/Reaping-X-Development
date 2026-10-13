--@ Push
local Jloader = require("@game/ReplicatedStorage/JLoader")
local PushLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/PushLibrary")

local PushComponent = {}

local SWING = "Push"
local BLEND = "Push/blend"
local COOLDOWN = "Push"

local pushRelay = nil

local function getPushRelay()
	pushRelay = pushRelay or Jloader.GetService("PushService")
	return pushRelay
end

function PushComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then return false end

	local StatusService = controller.StatusService

	if controller.CooldownService:CheckCooldown(Character, COOLDOWN) then
		return false
	end

	if StatusService:CheckStatuses(Character, {
		IsBlocking = true,
		IsRagdolled = true,
		IsDiving = true,
	}) or StatusService:IsHitYielded(Character) or StatusService:IsActionLocked(Character) then
		return false
	end

	return true
end

function PushComponent:Activate(controller, combatState)
	local Character = controller.Character

	if not PushComponent:CanActivate(controller, combatState) then return end

	local relay = getPushRelay()
	if not relay then return end

	local AttackService = controller.AttackService
	local StatusService = controller.StatusService

	local sprinting = StatusService:CheckStatuses(Character, { IsSprinting = true })
	local variant = sprinting and PushLibrary.Sprint or PushLibrary.Stand

	local track = AttackService:SwapTrack(controller, SWING, Character, variant.Animation, {
		Speed = 1,
		Weight = variant.Weight,
		Priority = PushLibrary.TrackPriority,
		FadeTime = PushLibrary.TrackFade,
		Loop = false,
	})

	AttackService:Cancel(controller, BLEND)

	if variant.BlendAt then
		AttackService:Schedule(controller, BLEND, variant.BlendAt, function()
			if AttackService:GetTrack(controller, SWING) == track then
				AttackService:StopTrack(controller, SWING, variant.BlendFade)
			end
		end)
	end

	relay.ReportPush:Fire(sprinting)

	AttackService:ScheduleHitbox(controller, SWING, Character, {
		hitbox = variant.Hitbox,
		hitbox_delay = variant.HitboxDelay,
		combo_index = 1,
	}, {
		weaponId = SWING,
		reaction = PushLibrary.Reaction,
		report = function(target)
			relay.ReportHit:Fire(target)
		end,
	})

	local impulse = variant.Impulse

	if impulse then
		AttackService:ScheduleImpulse(controller, SWING, Character, {
			impulse = impulse,
			impulse_delay = impulse.delay,
			impulse_priority = impulse.priority,
		}, {
			onLunge = function(_, direction)
				relay.ReportLunge:Fire({ direction.X, direction.Y, direction.Z })
			end,
		})
	end

	combatState.PushStatus = variant.Status

	StatusService:SetStatus(Character, variant.Status, true, variant.Duration)
	controller.CooldownService:ApplyCooldown(Character, COOLDOWN, PushLibrary.Cooldown)
end

function PushComponent:Deactivate(controller, combatState)
	controller.AttackService:Cancel(controller, BLEND)
	controller.AttackService:CancelSwing(controller, SWING)

	if controller.Character and combatState.PushStatus then
		controller.StatusService:RemoveStatus(controller.Character, combatState.PushStatus)
		combatState.PushStatus = nil
	end
end

return PushComponent
