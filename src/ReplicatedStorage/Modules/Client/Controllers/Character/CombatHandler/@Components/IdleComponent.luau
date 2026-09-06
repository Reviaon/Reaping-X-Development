--@ Idle Component
--@ Holds the equipped weapon's idle stance ({WeaponId}Idle) while the character is
local IdleComponent = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Animations")

local IDLE_PRIORITY = Enum.AnimationPriority.Action
local IDLE_SUFFIX = "Idle"
local FADE_TIME = 0.3

local BLOCKING_STATUSES = { "IsCrouching", "IsDiving" }

local AIRBORNE_STATES = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local SCOPE = "Idle"

local _animationExists = {}

local function animationExists(name: string): boolean
	local cached = _animationExists[name]
	if cached ~= nil then return cached end

	local found = Animations:FindFirstChild(name, true) ~= nil
	_animationExists[name] = found

	return found
end

local function stopIdle(controller)
	local state = controller:Scope(SCOPE)

	if not state.track then return end

	state.track:Stop(FADE_TIME)
	state.track = nil
	state.currentAnim = nil
end

--@ The whole point of the component: are they actually standing still?
local function shouldIdle(controller): boolean
	local Character = controller.Character
	local Humanoid = controller.Humanoid

	if not Character or not Humanoid then return false end
	if Humanoid.Health <= 0 then return false end

	if Humanoid.MoveDirection.Magnitude > 0 then return false end

	if Humanoid.FloorMaterial == Enum.Material.Air then return false end
	if AIRBORNE_STATES[Humanoid:GetState()] then return false end

	for _, status in BLOCKING_STATUSES do
		if controller.StatusService:CheckStatuses(Character, { [status] = true }) then
			return false
		end
	end

	return true
end

local function update(controller)
	local state = controller:Scope(SCOPE)

	if not shouldIdle(controller) then
		stopIdle(controller)
		return
	end

	local config = controller.CombatConfig
	if not config then
		stopIdle(controller)
		return
	end

	--@ Resolved every frame rather than read from _idle_animation: that field is only
	--@ refreshed on equip events, and an unequip recomputes it from an attribute that is
	--@ still stale at that moment, which left the last weapon's stance playing forever.
	local equipped = config:ResolveEquippedWeapon(controller)

	--@ Unarmed is not a stance.
	if not equipped then
		stopIdle(controller)
		return
	end

	local desired = equipped .. IDLE_SUFFIX

	--@ Weapon swapped out from under a playing idle
	if state.currentAnim and state.currentAnim ~= desired then
		stopIdle(controller)
	end

	if state.track and state.track.IsPlaying then return end
	if not animationExists(desired) then return end

	state.track = controller.AnimatorService:PlayTrack(controller.Character, desired, {
		Speed = 1,
		Priority = IDLE_PRIORITY,
		FadeTime = FADE_TIME,
		Loop = true,
	})

	state.currentAnim = desired
end

function IdleComponent:Init(controller)
	IdleComponent.Reset(controller)

	if not controller.Character then return end

	local state = controller:Scope(SCOPE)
	state.trove = controller.Trove.new()

	state.trove:Add(RunService.RenderStepped:Connect(function()
		update(controller)
	end))

	state.trove:Add(controller.Humanoid.Died:Connect(function()
		IdleComponent.Reset(controller)
	end))

	update(controller)
end

function IdleComponent.Reset(controller)
	if not controller then return end

	stopIdle(controller)

	local state = controller:Scope(SCOPE)

	if state.trove then
		state.trove:Clean()
		state.trove = nil
	end
end

return IdleComponent
