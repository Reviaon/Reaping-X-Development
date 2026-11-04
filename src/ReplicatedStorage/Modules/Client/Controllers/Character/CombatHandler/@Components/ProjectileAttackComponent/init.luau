local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@self/Config")
local Weapon = require("@self/Weapon")
local Cycle = require("@self/Cycle")
local Aim = require("@self/Aim")
local Nock = require("@self/Nock")
local Shot = require("@self/Shot")
local Observe = require("@self/Observe")

local ProjectileAttackComponent = {}

local function stateOf(controller)
	local state = controller:Scope(Config.Scope)

	if state.phase == nil then
		state.phase = "Idle"
		state.nocked = true
		state.held = false
		state.queued = false
		state.tracks = {}
	end

	return state
end

local function step(controller, dt: number)
	local state = stateOf(controller)
	local _, projectile = Weapon.Of(controller)

	if state.phase ~= "Idle" then
		if not projectile or Weapon.Cancelled(controller) then
			ProjectileAttackComponent:Deactivate(controller)
			return
		end

		if state.held and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			ProjectileAttackComponent:Release(controller)
		end

		Cycle.Advance(controller, state, projectile)
	end

	if projectile and controller.Character then
		Nock.Update(controller.Character, state, projectile)
	end

	Observe.Step(controller, dt)
end

local function aimStep(controller, state, dt: number)
	local Character = controller.Character
	if not Character then return end

	local _, projectile = Weapon.Of(controller)
	local active = state.phase ~= "Idle" and projectile ~= nil

	if active then
		Aim.Face(controller, state, projectile, dt)
	end

	local settings = projectile and projectile.arm_pitch or state.armSettings
	if not settings or (not active and (state.armPitch or 0) == 0) then return end

	Aim.PitchArms(Character, state, settings, if active then Aim.ShoulderPitch(Character, state.aimPoint) else 0, dt)
	Aim.SendPitch(controller, state)
end

function ProjectileAttackComponent:ObserveShot(controller, shooter, weaponId, origin, direction, firedAt)
	Shot.Observe(controller, shooter, weaponId, origin, direction, firedAt)
end

function ProjectileAttackComponent:CanActivate(controller, _combatState): boolean
	if not controller.Character then return false end

	local _, projectile = Weapon.Of(controller)
	if not projectile then return false end

	return not Weapon.Cancelled(controller)
end

function ProjectileAttackComponent:Activate(controller, combatState)
	ProjectileAttackComponent:Press(controller, combatState)
end

function ProjectileAttackComponent:Press(controller, combatState)
	local state = stateOf(controller)

	state.held = true
	state.combat = combatState or state.combat

	if state.phase ~= "Idle" then return end

	state.savedAutoRotate = controller.Humanoid and controller.Humanoid.AutoRotate
	controller.StatusService:SetStatus(controller.Character, Config.Status, true)
	Cycle.Enter(controller, state, if state.nocked then "Drawing" else "Reloading")
end

function ProjectileAttackComponent:Release(controller, _combatState)
	local state = stateOf(controller)

	state.held = false

	if state.phase == "Drawing" then
		state.queued = true
	elseif state.phase == "Holding" then
		Cycle.Enter(controller, state, "Firing")
	end
end

function ProjectileAttackComponent:Deactivate(controller, _combatState)
	local state = stateOf(controller)
	if state.phase == "Idle" then return end

	if state.phase == "Firing" and not state.released then
		state.nocked = true
	elseif state.phase == "Reloading" then
		state.nocked = false
	end

	Cycle.Finish(controller, state)
end

function ProjectileAttackComponent:Init(controller)
	ProjectileAttackComponent.Reset(controller)

	if not controller.Character then return end

	local state = stateOf(controller)
	state.trove = controller.Trove.new()

	state.trove:Add(RunService.RenderStepped:Connect(function(dt)
		step(controller, dt)
	end))

	RunService:BindToRenderStep(Config.Facing.Step, Config.Facing.Priority, function(dt)
		aimStep(controller, state, dt)
	end)
end

function ProjectileAttackComponent.Reset(controller)
	if not controller then return end

	local state = stateOf(controller)

	Cycle.Unwatch(state)
	Cycle.StopTracks(state, 0)
	RunService:UnbindFromRenderStep(Config.Facing.Step)

	if state.trove then
		state.trove:Clean()
		state.trove = nil
	end

	Nock.Reset(state)
	Aim.RestoreArms(state)
	Aim.HoldFov(nil, false)

	state.phase = "Idle"
	state.nocked = true
	state.held = false
	state.queued = false
	state.combat = nil
end

return ProjectileAttackComponent
