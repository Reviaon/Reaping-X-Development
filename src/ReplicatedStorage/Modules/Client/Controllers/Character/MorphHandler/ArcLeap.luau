local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

local Config = require("./Config")
local Types = require("./Types")

type Session = Types.Session

local ArcLeap = {}

local GlobalFunctions = Jloader.GlobalFunctions

local NO_ROTATE = "NoRotate"
local FLAT = Vector3.new(1, 0, 1)

local function floorBelow(position: Vector3, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	local hit = workspace:Raycast(position + Vector3.yAxis * Config.ArcProbeUp, Vector3.yAxis * -Config.ArcProbeDown, params)

	return hit and hit.Position.Y
end

local function standing(session: Session): number
	return session.Humanoid.HipHeight + session.Root.Size.Y / 2
end

local function seated(target: BasePart?): boolean
	return target ~= nil and target.Parent ~= nil and Players:GetPlayerFromCharacter(target.Parent) ~= nil
end

local function endPoint(session: Session, motion: Types.ArcMotion): Vector3
	local target = motion.Target
	local arc = motion.Arc
	local lands = arc.lands

	if target and target.Parent and lands and motion.Seat then
		local toward = (motion.Origin - target.Position) * FLAT
		local facing = if toward.Magnitude > 1e-3 then CFrame.lookAt(target.Position, target.Position + toward.Unit) else target.CFrame
		local point = facing:PointToWorldSpace(Vector3.new(lands.x, 0, lands.z))
		local floor = floorBelow(target.Position, { session.Character, target.Parent }) or target.Position.Y - Config.ArcVictimHeight

		return Vector3.new(point.X, floor + standing(session) + lands.y, point.Z)
	end

	local aim = if target and target.Parent then target.Position + target.AssemblyLinearVelocity * FLAT * motion.Lead else motion.Origin + motion.Direction * motion.Reach
	local offset = (aim - motion.Origin) * FLAT
	local along = if offset.Magnitude > 1e-3 then offset.Unit else motion.Direction
	local distance = math.min(math.max(offset.Magnitude - motion.Reach, 0), motion.Most)
	local landing = motion.Origin + along * distance
	local floor = floorBelow(landing, { session.Character })

	return Vector3.new(landing.X, if floor then floor + standing(session) else motion.Origin.Y, landing.Z)
end

local function trackOf(session: Session): AnimationTrack?
	local key = session.State.AbilityAnimation
	return if key then session.Animator:Playing(key) else nil
end

function ArcLeap.Start(session: Session, spec: { leap: Types.Leap?, reach: number, range: number?, windup: number, recovery: number?, speed: number? }, target: BasePart?, direction: Vector3, cap: number?)
	local jump = spec.leap :: Types.Leap
	local arc = jump.arc :: MorphTypes.LeapArc
	local now = os.clock()
	local root = session.Root
	local airtime = math.max(jump.airtime or 0, 1e-3)

	local motion: Types.ArcMotion = {
		Arc = arc,
		Target = target,
		Seat = seated(target) and arc.lands ~= nil,
		Origin = root.Position,
		Direction = direction,
		Lead = jump.lead or 0,
		Reach = spec.reach,
		Most = math.min((jump.max_speed or math.huge) * airtime, cap or math.huge),
		Start = root.Position,
		Landing = root.Position,
		Duration = airtime,
		Speed = spec.speed or 1,
		At = now,
		Until = now + math.max(spec.windup - (jump.delay or 0), airtime) + (spec.recovery or 0) + Config.ArcGrace,
		Stretched = false,
		Landed = false,
	}

	motion.Landing = endPoint(session, motion)

	local travel = (motion.Landing - motion.Origin) * FLAT

	if travel.Magnitude > motion.Most then
		local capped = motion.Origin + travel.Unit * motion.Most
		motion.Landing = Vector3.new(capped.X, motion.Landing.Y, capped.Z)
		motion.Seat = false
	end

	session.Burst:Stop()
	session.State.Arc = motion
	GlobalFunctions.StatusService:SetStatus(session.Character, NO_ROTATE, true, nil, Config.LungeFacing)
end

function ArcLeap.Active(session: Session): boolean
	return session.State.Arc ~= nil
end

function ArcLeap.Stop(session: Session)
	local motion = session.State.Arc
	if not motion then return end

	session.State.Arc = nil

	if not motion.Landed then
		local track = trackOf(session)

		if track then
			track:AdjustSpeed(motion.Speed)
		end
	end

	GlobalFunctions.StatusService:RemoveStatus(session.Character, NO_ROTATE, Config.LungeFacing)
end

function ArcLeap.Step(session: Session): boolean
	local motion = session.State.Arc
	if not motion then return false end

	local now = os.clock()
	local root = session.Root

	if now >= motion.Until then
		ArcLeap.Stop(session)
		return true
	end

	if motion.Landed then
		root.CFrame = CFrame.lookAt(motion.Landing, motion.Landing + (root.CFrame.LookVector * FLAT))
		root.AssemblyLinearVelocity = Vector3.zero
		return true
	end

	local dt = now - (motion.SteppedAt or motion.At)
	motion.SteppedAt = now

	local wanted = endPoint(session, motion)
	local shift = (wanted - motion.Landing) * FLAT
	local limit = (motion.Arc.home or Config.ArcHome) * dt

	if shift.Magnitude > limit then
		shift = shift.Unit * limit
	end

	motion.Landing += shift

	local s = math.clamp((now - motion.At) / motion.Duration, 0, 1)
	local arc = motion.Arc
	local position = motion.Start:Lerp(motion.Landing, s) + Vector3.yAxis * (4 * arc.height * s * (1 - s))
	local travel = (motion.Landing - motion.Start) * FLAT
	local look = if travel.Magnitude > 1e-3 then travel.Unit else motion.Direction
	local rise = 4 * arc.height * (1 - 2 * s) / motion.Duration

	root.CFrame = CFrame.lookAt(position, position + look)
	root.AssemblyLinearVelocity = (motion.Landing - motion.Start) / motion.Duration + Vector3.yAxis * rise

	local track = trackOf(session)

	if track and not motion.Stretched and track.TimePosition >= arc.hold then
		motion.Stretched = true

		local left = motion.At + motion.Duration - now

		if left > 1e-3 then
			track:AdjustSpeed(math.max(arc.resume - track.TimePosition, 0) / left)
		end
	end

	if s >= 1 then
		motion.Landed = true

		if track then
			track:AdjustSpeed(motion.Speed)
		end

		if not motion.Seat then
			ArcLeap.Stop(session)
		end
	end

	return true
end

return ArcLeap
