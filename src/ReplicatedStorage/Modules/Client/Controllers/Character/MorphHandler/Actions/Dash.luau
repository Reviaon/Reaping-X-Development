local DiveConfig = require("../../MovementHandler/@Components/DiveComponent/Config")

local Config = require("../Config")
local Types = require("../Types")
local Visuals = require("../Visuals")

type Session = Types.Session

local Dash = {}

local function sideOf(session: Session, direction: Vector3): string
	local relative = session.Root.CFrame:VectorToObjectSpace(direction)
	local forward, side = -relative.Z, relative.X

	if forward >= math.abs(side) then return "Forward" end
	if -forward >= math.abs(side) then return "Back" end

	return if side > 0 then "Right" else "Left"
end

local function held(session: Session): Vector3?
	local move = session.Humanoid.MoveDirection * Vector3.new(1, 0, 1)
	return if move.Magnitude > 1e-3 then move.Unit else nil
end

local function turnToward(current: Vector3, target: Vector3, dt: number): Vector3
	local alpha = 1 - math.exp(-DiveConfig.SprintTurnRate * dt)
	local turned = CFrame.lookAt(Vector3.zero, current):Lerp(CFrame.lookAt(Vector3.zero, target), alpha).LookVector * Vector3.new(1, 0, 1)

	return if turned.Magnitude > 1e-3 then turned.Unit else target
end

local function clipFor(session: Session, side: string): string?
	local dash = session.Profile.dash
	local animations: { [string]: string } = if dash and dash.animations then dash.animations else {}

	return animations[side]
end

local function swapClip(session: Session, motion: Types.DashMotion, side: string)
	local state = session.State
	local from = state.DashAnimation
	local next = clipFor(session, side)

	motion.Side = side
	if next == from then return end

	local playing = if from then session.Animator:Playing(from) else nil
	local position = if playing then playing.TimePosition else 0

	if from then
		session.Animator:Stop(from, Config.ActionFade)
	end

	local track = if next then session.Animator:Play(next, motion.Playback) else nil

	if track then
		track.TimePosition = position
	end

	state.DashAnimation = next
end

function Dash.Began(session: Session)
	local dash = session.Profile.dash
	if not dash then return end

	local tuning: Types.DashTuning = session.Entry.dash or {}
	local state = session.State
	local now = os.clock()

	if session:Busy(now) or now < (state.DashReadyAt or 0) or session:Yielded() then return end

	local direction = held(session) or -session:Look()
	local speed = tuning.speed or dash.speed
	local duration = (tuning.distance or Config.DashDistance) / speed
	local side = sideOf(session, direction)
	local clip = clipFor(session, side)
	local playback = dash.playback or 1

	state.BusyUntil = now + duration + (dash.recovery or 0)
	state.DashReadyAt = now + duration + (tuning.cooldown or Config.DashCooldown)
	state.DashAnimation = clip
	state.Dash = { Direction = direction, Speed = speed, Playback = playback, Side = side, At = now, Until = now + duration }

	session.Burst:Start(direction * speed, duration)

	if clip then
		session.Animator:Play(clip, playback)
	end

	Visuals.Shot(session, dash.visual, playback)
end

function Dash.Step(session: Session)
	local state = session.State
	local motion = state.Dash
	if not motion then return end

	local now = os.clock()

	if now >= motion.Until then
		state.Dash = nil
		return
	end

	local dt = now - motion.At
	local target = held(session)

	motion.At = now

	if target then
		motion.Direction = turnToward(motion.Direction, target, dt)
	end

	session.Burst:Steer(motion.Direction * motion.Speed)

	local side = sideOf(session, motion.Direction)

	if side ~= motion.Side then
		swapClip(session, motion, side)
	end
end

return Dash
