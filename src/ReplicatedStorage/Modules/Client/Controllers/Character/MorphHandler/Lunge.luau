local Jloader = require("@game/ReplicatedStorage/JLoader")
local MathService = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Utility/MathService")

local Config = require("./Config")
local Targets = require("./Targets")
local Types = require("./Types")

type Session = Types.Session

local Lunge = {}

local GlobalFunctions = Jloader.GlobalFunctions

local NO_ROTATE = "NoRotate"
local FLAT = Vector3.new(1, 0, 1)

local function turn(from: Vector3, to: Vector3, limit: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= limit or angle < 1e-4 then return to end

	local turned = CFrame.lookAt(Vector3.zero, from):Lerp(CFrame.lookAt(Vector3.zero, to), limit / angle).LookVector * FLAT

	return if turned.Magnitude > 1e-3 then turned.Unit else to
end

local function face(session: Session, direction: Vector3)
	local root = session.Root
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
end

local function alive(target: BasePart?): BasePart?
	if not target or not target.Parent then return nil end

	local humanoid = target.Parent:FindFirstChildOfClass("Humanoid")

	return if humanoid and humanoid.Health > 0 then target else nil
end

local function aimOf(motion: Types.LungeMotion, target: BasePart): Vector3
	return target.Position + target.AssemblyLinearVelocity * FLAT * motion.Lead
end

local function arrive(session: Session, motion: Types.LungeMotion, speed: number)
	motion.Arrived = true

	if motion.Overrun <= 0 or speed <= 1 then
		session.Burst:Stop()
		return
	end

	local now = os.clock()
	local duration = math.max(motion.Overrun * (Config.CoastEase + 1) / speed, motion.Settle)

	motion.Coast = { At = now, Speed = speed, Duration = duration }
	motion.Until = math.max(motion.Until, now + duration)
	session.Burst:Start(motion.Direction * speed, duration)
end

function Lunge.Stop(session: Session)
	if not session.State.Lunge then return end

	session.State.Lunge = nil
	session.Burst:Stop()
	GlobalFunctions.StatusService:RemoveStatus(session.Character, NO_ROTATE, Config.LungeFacing)
end

function Lunge.Release(session: Session)
	local motion = session.State.Lunge
	if not motion then return end

	if motion.Coast then
		motion.Target = nil
		return
	end

	Lunge.Stop(session)
end

function Lunge.Start(session: Session, lunge: Types.Lunge)
	local now = os.clock()

	Lunge.Stop(session)

	session.State.Lunge = {
		Target = lunge.Target,
		Direction = lunge.Direction,
		Speed = lunge.Speed,
		Distance = lunge.Distance,
		Track = lunge.Track,
		Lead = lunge.Lead,
		Stop = lunge.Stop,
		Origin = session.Root.Position,
		Arrived = lunge.Speed <= 0 or lunge.Distance <= 0,
		Ease = lunge.Ease,
		Rise = lunge.Rise,
		Overrun = lunge.Overrun,
		Settle = lunge.Settle,
		Coast = nil,
		Started = now,
		Duration = lunge.Duration,
		At = now,
		Until = now + math.max(lunge.Hold, lunge.Duration),
	}

	GlobalFunctions.StatusService:SetStatus(session.Character, NO_ROTATE, true, nil, Config.LungeFacing)
	face(session, lunge.Direction)

	if lunge.Speed > 0 and lunge.Distance > 0 then
		session.Burst:Start(lunge.Direction * lunge.Speed * MathService.Surge(0, lunge.Rise, lunge.Ease), lunge.Duration)
	end
end

function Lunge.Leap(session: Session, spec: { leap: Types.Leap?, reach: number, range: number?, windup: number }, cap: number?)
	local jump = spec.leap
	if not jump then return end

	local root = session.Root
	local delay = jump.delay or 0
	local airtime = math.max(jump.airtime or (spec.windup - delay), 1e-3)
	local limit = cap or math.huge
	local top = jump.max_speed or jump.speed or 0
	local target = Targets.Ahead(session, spec.range or 0, Config.LeapCone)
	local direction = session:Look()
	local distance, speed

	if target then
		local offset = (target.Position + target.AssemblyLinearVelocity * FLAT * (jump.lead or 0) - root.Position) * FLAT

		distance = math.min(math.max(offset.Magnitude - spec.reach, 0), limit)
		speed = jump.speed or math.min(distance / (airtime * Config.LeapArrival), top)

		if offset.Magnitude > 1e-3 then
			direction = offset.Unit
		end
	else
		distance = math.min(top * airtime, limit)
		speed = jump.speed or distance / airtime
	end

	Lunge.Start(session, {
		Target = target,
		Direction = direction,
		Speed = speed,
		Distance = distance,
		Track = math.rad(jump.track or 0),
		Lead = jump.lead or 0,
		Stop = spec.reach,
		Ease = 0,
		Rise = 0,
		Overrun = jump.overrun or 0,
		Settle = jump.settle or 0,
		Duration = airtime,
		Hold = math.max(spec.windup - delay, airtime),
	})
end

function Lunge.Bite(session: Session, spec: Types.BiteSpec, tuning: Types.BiteTuning, lead: number)
	local distance = tuning.lunge or 0
	local target = Targets.Ahead(session, tuning.range or 0, tuning.cone or 0)
	local direction = session:Look()

	if target then
		local offset = (target.Position - session.Root.Position) * FLAT

		if offset.Magnitude > 1e-3 then
			direction = offset.Unit
		end
	end

	if distance <= 0 and not target then return end

	local ease = spec.step_in_ease or 0
	local rise = spec.step_in_rise or 0

	Lunge.Start(session, {
		Target = target,
		Direction = direction,
		Speed = distance / (math.max(lead, 1e-3) * MathService.SurgeShare(rise, ease)),
		Distance = distance,
		Track = math.rad(tuning.track or 0),
		Lead = 0,
		Stop = spec.reach * Config.LungeDepth,
		Ease = ease,
		Rise = rise,
		Overrun = 0,
		Settle = 0,
		Duration = lead,
		Hold = lead,
	})
end

function Lunge.Step(session: Session)
	local motion = session.State.Lunge
	if not motion then return end

	local now = os.clock()
	local coasting = motion.Coast

	if coasting then
		local progress = (now - coasting.At) / coasting.Duration

		if progress >= 1 then
			Lunge.Stop(session)
			return
		end

		session.Burst:Steer(motion.Direction * coasting.Speed * (1 - progress) ^ Config.CoastEase)
		face(session, motion.Direction)

		return
	end

	if now >= motion.Until then
		if motion.Arrived or motion.Overrun <= 0 then
			Lunge.Stop(session)
		else
			arrive(session, motion, motion.Speed)
		end

		return
	end

	local dt = now - motion.At
	local root = session.Root
	local target = alive(motion.Target)
	local speed = motion.Speed * MathService.Surge((now - motion.Started) / motion.Duration, motion.Rise, motion.Ease)

	motion.At = now

	if target then
		local offset = (aimOf(motion, target) - root.Position) * FLAT

		if offset.Magnitude > 1e-3 then
			motion.Direction = turn(motion.Direction, offset.Unit, motion.Track * dt)
		end

		if not motion.Arrived and offset.Magnitude - motion.Stop <= math.max(speed * dt, 0.25) then
			arrive(session, motion, speed)
		end
	end

	if not motion.Arrived then
		if ((root.Position - motion.Origin) * FLAT).Magnitude >= motion.Distance then
			arrive(session, motion, speed)
		else
			session.Burst:Steer(motion.Direction * speed)
		end
	end

	face(session, motion.Direction)
end

return Lunge
