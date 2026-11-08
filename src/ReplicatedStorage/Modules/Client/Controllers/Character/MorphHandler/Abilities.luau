local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("./Config")
local Targets = require("./Targets")
local Types = require("./Types")

type Session = Types.Session
type Ability = Types.Ability

local Abilities = {}

local GlobalFunctions = Jloader.GlobalFunctions

local ATTACKING = "IsAttacking"
local NO_ROTATE = "NoRotate"
local FLAT = Vector3.new(1, 0, 1)

local function specOf(session: Session, name: string): Ability?
	for _, ability in session.Profile.abilities do
		if ability.name == name then
			return ability
		end
	end

	return nil
end

local function readyIn(tool: Tool): number
	local readyAt = tool:GetAttribute(GlobalFunctions.CharacterService.MorphReadyAttribute)
	return if typeof(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
end

local function release(session: Session)
	if not session.State.Leap then return end

	session.State.Leap = nil
	GlobalFunctions.StatusService:RemoveStatus(session.Character, NO_ROTATE, Config.LeapFacing)
end

local function landingFor(session: Session, motion: Types.LeapMotion): Vector3?
	local target = motion.Target
	if not target or not target.Parent then return nil end

	local aim = target.Position + target.AssemblyLinearVelocity * FLAT * motion.Lead
	local offset = (aim - session.Root.Position) * FLAT

	if offset.Magnitude <= 1e-3 then return aim end

	return aim - offset.Unit * math.min(motion.Reach, offset.Magnitude)
end

local function face(session: Session, direction: Vector3)
	local root = session.Root
	local flat = direction * FLAT

	if flat.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end

local function leap(session: Session, spec: Ability)
	local jump = spec.leap
	if not jump or session.State.Ability ~= spec.name then return end

	local now = os.clock()
	local root = session.Root
	local delay = jump.delay or 0
	local airtime = jump.airtime or math.max(spec.windup - delay, 0)
	local motion: Types.LeapMotion = {
		Target = Targets.Ahead(session, spec.range or 0, Config.LeapCone),
		Landing = nil,
		Direction = session:Look(),
		Speed = jump.speed or jump.max_speed or 0,
		Lead = jump.lead or 0,
		Reach = spec.reach,
		Homing = jump.homing == true,
		Arrived = false,
		At = now,
		Until = now + math.max(spec.windup - delay, airtime),
	}

	local landing = landingFor(session, motion)

	if landing then
		local travel = (landing - root.Position) * FLAT

		motion.Landing = landing
		motion.Speed = jump.speed or math.min(travel.Magnitude / math.max(airtime * Config.LeapArrival, 1e-3), jump.max_speed or math.huge)

		if travel.Magnitude > 1e-3 then
			motion.Direction = travel.Unit
		end
	end

	session.State.Leap = motion

	GlobalFunctions.StatusService:SetStatus(session.Character, NO_ROTATE, true, nil, Config.LeapFacing)
	face(session, motion.Direction)
	session.Burst:Start(motion.Direction * motion.Speed, airtime)
end

local function steer(session: Session)
	local motion = session.State.Leap
	if not motion then return end

	local now = os.clock()

	if now >= motion.Until then
		release(session)
		return
	end

	local dt = now - motion.At
	local root = session.Root

	motion.At = now

	if motion.Homing and not motion.Arrived then
		motion.Landing = landingFor(session, motion) or motion.Landing
	end

	local landing = motion.Landing

	if landing and not motion.Arrived then
		local remaining = (landing - root.Position) * FLAT

		if remaining.Magnitude <= math.max(motion.Speed * dt, 0.5) or remaining:Dot(motion.Direction) <= 0 then
			motion.Arrived = true
			session.Burst:Stop()
		else
			motion.Direction = remaining.Unit
			session.Burst:Steer(motion.Direction * motion.Speed)
		end
	end

	local target = motion.Target
	local facing = if target and target.Parent then (target.Position - root.Position) * FLAT else motion.Direction

	face(session, if facing.Magnitude > 1e-3 then facing else motion.Direction)
end

local function finish(session: Session)
	local state = session.State

	release(session)
	state.Attacking = false
	state.Ability = nil
	state.AbilityAnimation = nil
	session:Speed()
end

local function abandon(session: Session)
	local state = session.State

	session:Cancel("Ability")
	session.Burst:Stop()
	session.Animator:Stop(state.AbilityAnimation)
	state.BusyUntil = nil
	GlobalFunctions.StatusService:RemoveStatus(session.Character, ATTACKING)
	finish(session)
end

local function miss(session: Session, spec: Ability)
	local state = session.State
	local from = state.AbilityAnimation
	local next = spec.miss_animation
	if not from or not next then return end

	local playing = session.Animator:Playing(from)
	local position = if playing then playing.TimePosition else 0

	session.Animator:Stop(from, Config.MissFade)

	local track = session.Animator:Play(next, spec.speed)

	if track then
		track.TimePosition = position
	end

	state.AbilityAnimation = next
end

local function resolve(session: Session, name: unknown, result: unknown)
	local spec = if typeof(name) == "string" then specOf(session, name) else nil
	if not spec or session.State.Ability ~= spec.name then return end

	if result == "Missed" or result == "Landed" then
		release(session)
		session.Burst:Stop()
	end

	if result == "Missed" then
		miss(session, spec)
	elseif result == "Rejected" or result == "Interrupted" then
		abandon(session)
	end
end

local function watch(session: Session, child: Instance)
	if not child:IsA("Tool") or session.Tools[child] then return end

	local name = child:GetAttribute(GlobalFunctions.CharacterService.MorphAbilityAttribute)
	if typeof(name) ~= "string" then return end

	session.Tools[child] = name

	session.Trove:Connect(child.Activated, function()
		Abilities.Try(session, name, child)
	end)

	session.Trove:Connect(child.AncestryChanged, function()
		if not child:IsDescendantOf(game) then
			session.Tools[child] = nil
		end
	end)
end

function Abilities.Try(session: Session, name: string, tool: Tool)
	local spec = specOf(session, name)
	local now = os.clock()
	local state = session.State

	if not spec or session:Busy(now) or session:Yielded() or readyIn(tool) > 0 then return end

	local swing = spec.windup + spec.recovery

	state.BusyUntil = now + swing
	state.NextBiteAt = math.max(state.NextBiteAt or 0, now + swing + spec.cooldown)
	state.Attacking = true
	state.StepIn = 0
	state.Ability = name
	state.AbilityAnimation = spec.animation

	GlobalFunctions.StatusService:SetStatus(session.Character, ATTACKING, true, swing)
	session:Speed()

	if spec.animation then
		session.Animator:Play(spec.animation, spec.speed)
	end

	session.Service.Ability:Fire(name)

	if spec.leap then
		session:Delay("Ability", spec.leap.delay or 0, function()
			leap(session, spec)
		end)
	end

	session:Delay("Ability", swing, function()
		finish(session)
	end)
end

function Abilities.Start(session: Session)
	local backpack = Players.LocalPlayer:FindFirstChildOfClass("Backpack")

	session.Trove:Connect(session.Service.Ability, function(name: unknown, result: unknown)
		resolve(session, name, result)
	end)

	for _, holder in { backpack, session.Character } do
		if not holder then continue end

		for _, child in holder:GetChildren() do
			watch(session, child)
		end

		session.Trove:Connect(holder.ChildAdded, function(child: Instance)
			watch(session, child)
		end)
	end
end

function Abilities.Held(session: Session): boolean
	local tool = session.Character:FindFirstChildOfClass("Tool")
	return tool ~= nil and session.Tools[tool] ~= nil
end

function Abilities.Release(session: Session)
	release(session)
end

function Abilities.Step(session: Session)
	steer(session)

	for tool, name in session.Tools do
		local spec = specOf(session, name)
		local label = if spec then spec.label else name
		local left = readyIn(tool)
		local text = if left > 0 then `{label} {math.ceil(left)}` else label

		if tool.Name ~= text then
			tool.Name = text
		end
	end
end

return Abilities
