local Arc = require("../../Body/Arc")
local Attacks = require("../../Combat/Attacks")
local Tempo = require("../../Combat/Tempo")

local ATTACKING = "IsAttacking"
local MARKER_GRACE = 0.5
local AIRTIME_EFFICIENCY = 0.75
local STEP_IN_DEPTH = 0.7
local LEAP_ARRIVE = 1.5
local LIFT_GRACE = 0.25
local FLAT = Vector3.new(1, 0, 1)

local function face(mob)
	local root = mob:TargetRoot()

	if root then
		mob:Face(root.Position)
	end
end

local function turn(from: Vector3, to: Vector3, limit: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= limit or angle < 1e-4 then return to end

	local turned = CFrame.lookAt(Vector3.zero, from):Lerp(CFrame.lookAt(Vector3.zero, to), limit / angle).LookVector * FLAT

	return if turned.Magnitude > 1e-3 then turned.Unit else to
end

local function leap(mob, spec, data)
	local leapSpec = spec.leap
	local aim = mob:LeadPoint(leapSpec.lead or 0)
	local landing = mob:EngagePoint(aim, spec.reach)
	local travel = (landing - mob.Root.Position) * FLAT
	local look = mob.Root.CFrame.LookVector * FLAT
	local speed = leapSpec.speed

	if leapSpec.airtime then
		speed = math.min(travel.Magnitude / (leapSpec.airtime * (leapSpec.arrival or AIRTIME_EFFICIENCY)), leapSpec.max_speed or math.huge)
	end

	data.LeapSpeed = speed
	mob:Coast(leapSpec.overrun, leapSpec.settle)
	data.LeapHeading = if travel.Magnitude > 1e-3 then travel.Unit elseif look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	data.SteeredAt = os.clock()

	mob:Face(aim)
	mob:MoveTo(landing, speed)
	mob:Burst(speed, leapSpec.airtime)
end

local function seatOf(mob, spec, origin: Vector3): CFrame?
	local target = mob:GetTarget()
	if not target then return nil end

	local _, placed = mob.Services.PairSceneService.Place(spec.cinematic, mob.Model, target, origin)

	return placed and placed * CFrame.new(spec.leap.arc.seat)
end

local function arcLeap(mob, spec, data)
	local leapSpec = spec.leap
	local arc = leapSpec.arc
	local lead = leapSpec.lead or 0
	local origin = mob.Root.Position
	local most = (leapSpec.max_speed or math.huge) * leapSpec.airtime
	local seat = arc.seat and spec.cinematic and seatOf(mob, spec, origin)
	local landing = if seat then seat.Position else mob:EngagePoint(mob:LeadPoint(lead), spec.reach)
	local travel = (landing - origin) * FLAT
	local anchor = mob:TargetRoot()
	local anchorAt = anchor and anchor.Position

	if travel.Magnitude > most then
		landing = Vector3.new(origin.X, landing.Y, origin.Z) + travel.Unit * most
	end

	spec.from = origin

	local track = data.Track
	local speed = spec.speed or 1

	data.Arcing = true

	Arc.Begin(mob, landing, leapSpec.airtime, arc.height, {
		Home = arc.home,
		Airborne = seat ~= nil,
		Hold = seat ~= nil,
		Aim = function()
			local root = mob:TargetRoot()
			if not root then return nil end

			if seat and anchorAt then
				return seat.Position + (root.Position - anchorAt) * FLAT
			end

			return mob:EngagePoint(mob:LeadPoint(lead), spec.reach)
		end,
		OnStep = function()
			if data.Stretched or not track or track.TimePosition < arc.hold then return end

			data.Stretched = true

			local left = Arc.Remaining(mob)

			if left > 1e-3 then
				track:AdjustSpeed(math.max(arc.resume - track.TimePosition, 0) / left)
			end
		end,
		OnLand = function()
			data.Landed = true

			if track then
				track:AdjustSpeed(speed)
			end
		end,
	})
end

local function leapDue(spec, data, elapsed: number): boolean
	local delay = spec.leap.delay or 0
	local track = data.Track

	if spec.leap.arc and track and track.IsPlaying then
		return track.TimePosition >= delay or elapsed >= delay + LIFT_GRACE
	end

	return elapsed >= delay
end

local function steer(mob, spec, data)
	local root = mob:TargetRoot()
	if not root or mob.Coasting then return end

	local now = os.clock()
	local dt = now - data.SteeredAt
	local landing = mob:EngagePoint(mob:LeadPoint(spec.leap.lead or 0), spec.reach)
	local offset = (landing - mob.Root.Position) * FLAT

	data.SteeredAt = now

	if offset.Magnitude <= LEAP_ARRIVE then return end

	data.LeapHeading = turn(data.LeapHeading, offset.Unit, math.rad(spec.leap.track) * dt)

	local point = mob.Root.Position + data.LeapHeading * offset.Magnitude

	mob:Face(point)
	mob:MoveTo(point, data.LeapSpeed)
end

local function stepIn(mob, spec, data, elapsed: number)
	local root = mob:TargetRoot()
	if not root then return end

	if not data.Stepping then
		mob:Surge(spec.step_in, spec.windup - elapsed, spec.step_in_ease, spec.step_in_rise)
	end

	data.Stepping = true
	mob:MoveTo(mob:EngagePoint(root.Position, spec.reach * STEP_IN_DEPTH), spec.step_in)
end

local function strikeDue(spec, data, elapsed: number): boolean
	local arc = spec.leap and spec.leap.arc

	if arc and data.Arcing then
		local track = data.Track
		local contact = data.Landed and (not track or not track.IsPlaying or track.TimePosition >= arc.contact)

		return contact or elapsed >= spec.windup + MARKER_GRACE
	end

	if not spec.marker then
		return elapsed >= spec.windup
	end

	return data.MarkerReached or elapsed >= spec.windup + MARKER_GRACE
end

local function specFor(mob, args)
	local blackboard = mob.Blackboard
	local name = args and args.ability and blackboard.PendingAbility

	if name then
		blackboard.PendingAbility = nil
		blackboard.Setup = nil
		return Attacks.Ability(mob, name)
	end

	local index = Attacks.NextIndex(mob)
	blackboard.Combo = index

	return Attacks.Spec(mob, index)
end

local function follow(mob, data, landed: boolean)
	local spec = data.Spec

	if landed and spec.cinematic then
		data.Animation = nil
		return
	end

	local next = if landed then spec.hit_animation else spec.miss_animation
	if not next or not data.Animation then return end

	local position = mob.Animation:Position(data.Animation)

	mob.Animation:Stop(data.Animation, 0.05)
	mob.Animation:PlayAction(next, spec.speed, position)
	data.Animation = next
end

return {
	Enter = function(mob, data, args)
		local spec = specFor(mob, args)
		local swing = spec.windup + spec.recovery
		local blackboard = mob.Blackboard
		local now = os.clock()

		blackboard.LastAttackAt = now
		blackboard.NextAttackAt = now + swing + spec.cooldown

		data.Spec = spec
		data.Duration = swing

		if spec.ability then
			blackboard.AbilityReadyAt[spec.ability] = now + (spec.ability_cooldown or 0)

			local fight = mob:Fight()

			if fight and mob.Target then
				fight:Reserve(mob.Target, spec.reserve or spec.ability, math.max(swing, spec.team_cooldown or 0))
			end
		else
			Tempo.Note(mob)

			local fight = mob:Fight()

			if fight then
				fight:NoteAttack(mob)
			end
		end

		mob:Stop()
		face(mob)
		Attacks.Press(mob, spec)
		Attacks.Visual(mob, spec)

		if spec.animation then
			data.Animation = spec.animation

			local track = mob.Animation:PlayAction(spec.animation, spec.speed)
			data.Track = track

			if track and spec.marker then
				data.Marker = track:GetMarkerReachedSignal(spec.marker):Connect(function()
					data.MarkerReached = true
				end)
			end
		end

		mob.Services.StatusService:SetStatus(mob.Model, ATTACKING, true, swing)
	end,

	Update = function(mob, data, _, elapsed)
		local spec = data.Spec

		if spec.leap and not data.Leapt and leapDue(spec, data, elapsed) then
			data.Leapt = true

			if spec.leap.arc and spec.leap.airtime then
				arcLeap(mob, spec, data)
			else
				leap(mob, spec, data)
			end
		elseif spec.leap and (spec.leap.track or 0) > 0 and data.Leapt and not data.Hit then
			steer(mob, spec, data)
		end

		if not data.Hit then
			if not data.Leapt or not spec.leap then
				face(mob)
			end

			if not spec.leap and (spec.step_in or 0) > 0 and elapsed >= spec.windup - (spec.step_in_lead or spec.windup) then
				stepIn(mob, spec, data, elapsed)
			end

			if strikeDue(spec, data, elapsed) then
				data.Hit = true

				if data.Arcing then
					Arc.Stop(mob)
				end

				local hits = mob:Strike(spec)
				local coasting = data.Leapt and mob:CoastOut()

				mob:Coast(nil)

				if (data.Leapt or data.Stepping) and not coasting then
					mob:Stop()
				end

				follow(mob, data, hits > 0)
			end
		end

		if elapsed >= data.Duration then
			data.Done = true
		end
	end,

	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Exit = function(mob, data)
		if data.Arcing then
			Arc.Stop(mob)
		end

		mob:Unface()
		mob:Coast(nil)

		if data.Marker then
			data.Marker:Disconnect()
		end

		if data.Leapt or data.Stepping then
			mob:Stop()
		end

		if data.Done then return end

		if data.Animation then
			mob.Animation:Stop(data.Animation)
		end

		mob.Services.StatusService:RemoveStatus(mob.Model, ATTACKING)
	end,
}
