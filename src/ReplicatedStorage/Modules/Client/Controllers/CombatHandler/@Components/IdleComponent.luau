--@ Idle Component
--@ Holds the equipped weapon's idle stance ({WeaponId}Idle) while the character is
local IdleComponent = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Animations")

local IDLE_PRIORITY = Enum.AnimationPriority.Idle
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

local _trove = nil
local _track = nil
local _currentAnim = nil

local _animationExists = {}

local function animationExists(name: string): boolean
	local cached = _animationExists[name]
	if cached ~= nil then return cached end

	local found = Animations:FindFirstChild(name, true) ~= nil
	_animationExists[name] = found

	return found
end

local function stopIdle()
	if not _track then return end

	_track:Stop(FADE_TIME)
	_track = nil
	_currentAnim = nil
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
	if not shouldIdle(controller) then
		stopIdle()
		return
	end

	local config = controller.CombatConfig
	if not config then
		stopIdle()
		return
	end

	--@ Resolved every frame rather than read from _idle_animation: that field is only
	--@ refreshed on equip events, and an unequip recomputes it from an attribute that is
	--@ still stale at that moment, which left the last weapon's stance playing forever.
	local equipped = config:ResolveEquippedWeapon(controller)

	--@ Unarmed is not a stance.
	if not equipped then
		stopIdle()
		return
	end

	local desired = equipped .. IDLE_SUFFIX

	--@ Weapon swapped out from under a playing idle
	if _currentAnim and _currentAnim ~= desired then
		stopIdle()
	end

	if _track and _track.IsPlaying then return end
	if not animationExists(desired) then return end

	_track = controller.AnimatorService:PlayTrack(controller.Character, desired, {
		Speed = 1,
		Priority = IDLE_PRIORITY,
		FadeTime = FADE_TIME,
		Loop = true,
	})

	_currentAnim = desired
end

function IdleComponent:Init(controller)
	IdleComponent.Reset()

	if not controller.Character then return end

	_trove = controller.Trove.new()

	_trove:Add(RunService.RenderStepped:Connect(function()
		update(controller)
	end))

	_trove:Add(controller.Humanoid.Died:Connect(function()
		IdleComponent.Reset()
	end))

	update(controller)
end

function IdleComponent.Reset()
	stopIdle()

	if _trove then
		_trove:Clean()
		_trove = nil
	end
end

return IdleComponent
