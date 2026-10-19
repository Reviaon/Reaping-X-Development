--@ Block Component
local Jloader = require("@game/ReplicatedStorage/JLoader")
local BlockLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/BlockLibrary")

local BlockComponent = {}

local SCOPE = "Block"

local Animations = BlockLibrary.Animations

local function weaponOf(controller)
	return controller.CombatConfig:ResolveWeaponId(controller)
end

local function idleFor(controller)
	local name = weaponOf(controller) .. Animations.IdleSuffix

	if controller.AnimatorService:HasAnimation(name) then
		return name
	end

	return Animations.UniversalIdle
end

local function reactionsFor(controller)
	local prefix = weaponOf(controller) .. Animations.ReactionSuffix
	local names = {}

	while controller.AnimatorService:HasAnimation(prefix .. (#names + 1)) do
		table.insert(names, prefix .. (#names + 1))
	end

	return names
end

local function report(controller, raised)
	local relay = controller.BlockRelay

	if relay then
		relay.ReportBlock:Fire(raised)
	end
end

--@ Tracks live in this component's scope, not AttackService's: a dive releases every AttackService
--@ track with no live hitbox, which took the block idle with it.
local function stopTrack(state, key)
	local track = state[key]

	if track then
		track:Stop(Animations.IdleFade)
		state[key] = nil
	end
end

local function playIdle(controller)
	local state = controller:Scope(SCOPE)
	local name = idleFor(controller)

	if state.idle and state.idle.IsPlaying and state.idle.Name == name then return end

	stopTrack(state, "idle")

	state.idle = controller.AnimatorService:PlayTrack(controller.Character, name, {
		Speed = 1,
		Priority = Animations.IdlePriority,
		FadeTime = Animations.IdleFade,
		Loop = true,
	})
end

--@ force plays it with the guard already down: a break's GuardBroken can replicate before the
--@ Broken event, and the yield interrupt lowers the guard first.
local function react(controller, force)
	local state = controller:Scope(SCOPE)
	local reactions = reactionsFor(controller)

	if not (state.raised or force) or not controller.Character or #reactions == 0 then return end

	state.reaction = state.reaction % #reactions + 1

	if state.reactionTrack then
		state.reactionTrack:Stop(Animations.ReactionFade)
	end

	state.reactionTrack = controller.AnimatorService:PlayTrack(controller.Character, reactions[state.reaction], {
		Speed = 1,
		Priority = Animations.ReactionPriority,
		FadeTime = Animations.ReactionFade,
		Loop = false,
	})
end

--@ False when there is no break animation, so the caller falls back to a reaction.
local function playBreak(controller): boolean
	local Character = controller.Character

	if not Character or not controller.AnimatorService:HasAnimation(Animations.Break) then
		return false
	end

	local state = controller:Scope(SCOPE)

	stopTrack(state, "reactionTrack")

	local track = controller.AnimatorService:GetTrack(Character, Animations.Break)
	local remaining = controller.StatusService:GetRemainingTime(Character, BlockLibrary.BrokenStatus)
		or BlockLibrary.BreakLockout

	state.breakTrack = controller.AnimatorService:PlayTrack(Character, Animations.Break, {
		Speed = (track.Length > 0 and remaining > 0) and track.Length / remaining or 1,
		Priority = Animations.BreakPriority,
		FadeTime = Animations.BreakFade,
		Loop = false,
	})

	return true
end

--@ True if the guard was up. A broken guard keeps its last reaction playing out.
local function lower(controller, keepReaction)
	local Character = controller.Character
	local state = controller:Scope(SCOPE)
	local wasRaised = state.raised == true

	state.raised = false

	stopTrack(state, "idle")

	if keepReaction then
		state.reactionTrack = nil
	else
		stopTrack(state, "reactionTrack")
	end

	if Character and controller.StatusService:CheckStatuses(Character, { IsBlocking = true }) then
		controller.StatusService:RemoveStatus(Character, "IsBlocking")
	end

	return wasRaised
end

function BlockComponent:Init(controller)
	local state = controller:Scope(SCOPE)

	state.raised = false
	state.repress = false
	state.reaction = 0
	state.idle = nil
	state.reactionTrack = nil
end

function BlockComponent:CanActivate(controller, _combatState): boolean
	local Character = controller.Character
	if not Character then
		return false
	end

	local state = controller:Scope(SCOPE)

	if state.raised or state.repress or os.clock() < (state.retryAt or 0) then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, {
		IsAttacking = true,
		IsCrouching = true,
		[BlockLibrary.LockStatus] = true,
	}) or controller.StatusService:IsHitYielded(Character) or controller.StatusService:IsActionLocked(Character) then
		return false
	end

	return true
end

function BlockComponent:Activate(controller, combatState)
	if not BlockComponent:CanActivate(controller, combatState) then
		return
	end

	local state = controller:Scope(SCOPE)

	state.raised = true
	state.reaction = 0

	playIdle(controller)
	controller.StatusService:SetStatus(controller.Character, "IsBlocking", true)
	report(controller, true)
end

--@ released is true when the block input itself was let go. A guard a stun knocked down stays down
--@ through a held input until that input is released and pressed again.
function BlockComponent:Deactivate(controller, _combatState, released: boolean?)
	local Character = controller.Character
	local StatusService = controller.StatusService
	local state = controller:Scope(SCOPE)

	local yielded = Character ~= nil and StatusService:IsHitYielded(Character)
	local stunned = Character ~= nil and StatusService:CheckStatuses(Character, { IsStunned = true })

	if lower(controller, yielded) then
		report(controller, false)

		if stunned then
			state.repress = true
		end
	end

	if released then
		state.repress = false
	end
end

function BlockComponent:Refresh(controller)
	if controller:Scope(SCOPE).raised and controller.Character then
		playIdle(controller)
	end
end

--@ The server's word on the guard: Absorbed and Broken are blocked hits, Refused a raise it
--@ turned down.
function BlockComponent:OnGuard(controller, event)
	local shape = BlockLibrary.Shakes[event]
	local camera = shape and Jloader.GetHandler("CameraHandler")

	if camera then
		camera:Shake(shape)
	end

	if event == "Absorbed" then
		react(controller)
	elseif event == "Broken" then
		if not playBreak(controller) then
			react(controller, true)
		end

		lower(controller, true)
		controller:Scope(SCOPE).retryAt = os.clock() + BlockLibrary.RetryDelay
	elseif event == "Refused" then
		lower(controller, false)
		controller:Scope(SCOPE).retryAt = os.clock() + BlockLibrary.RetryDelay
	end
end

return BlockComponent
