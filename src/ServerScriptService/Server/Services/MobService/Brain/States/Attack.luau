local Attacks = require("../../Combat/Attacks")

local ATTACKING = "IsAttacking"
local MARKER_GRACE = 0.5
local AIRTIME_EFFICIENCY = 0.75
local STEP_IN_DEPTH = 0.7

local function face(mob)
	local root = mob:TargetRoot()

	if root then
		mob:Face(root.Position)
	end
end

local function leap(mob, spec, data)
	local leapSpec = spec.leap
	local aim = mob:LeadPoint(leapSpec.lead or 0)
	local landing = mob:EngagePoint(aim, spec.reach)
	local speed = leapSpec.speed

	if leapSpec.airtime then
		local travel = (landing - mob.Root.Position) * Vector3.new(1, 0, 1)
		speed = math.min(travel.Magnitude / (leapSpec.airtime * AIRTIME_EFFICIENCY), leapSpec.max_speed or math.huge)
	end

	data.LeapSpeed = speed

	mob:Face(aim)
	mob:MoveTo(landing, speed)
	mob:Burst(speed, leapSpec.airtime)
end

local function steer(mob, spec, data)
	local root = mob:TargetRoot()
	if not root then return end

	mob:Face(root.Position)
	mob:MoveTo(mob:EngagePoint(root.Position, spec.reach), data.LeapSpeed)
end

local function stepIn(mob, spec, data)
	local root = mob:TargetRoot()
	if not root then return end

	data.Stepping = true
	mob:MoveTo(mob:EngagePoint(root.Position, spec.reach * STEP_IN_DEPTH), spec.step_in)
end

local function strikeDue(spec, data, elapsed: number): boolean
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

			if mob.Team and mob.Target then
				mob.Team:Reserve(mob.Target, spec.reserve or spec.ability, math.max(swing, spec.team_cooldown or 0))
			end
		elseif mob.Team then
			mob.Team:NoteAttack(mob)
		end

		mob:Stop()
		face(mob)
		Attacks.Press(mob, spec)
		Attacks.Visual(mob, spec)

		if spec.animation then
			data.Animation = spec.animation

			local track = mob.Animation:PlayAction(spec.animation, spec.speed)

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

		if spec.leap and not data.Leapt and elapsed >= (spec.leap.delay or 0) then
			data.Leapt = true
			leap(mob, spec, data)
		elseif spec.leap and spec.leap.homing and data.Leapt and not data.Hit then
			steer(mob, spec, data)
		end

		if not data.Hit then
			if not data.Leapt or not spec.leap then
				face(mob)
			end

			if not spec.leap and (spec.step_in or 0) > 0 then
				stepIn(mob, spec, data)
			end

			if strikeDue(spec, data, elapsed) then
				data.Hit = true

				local hits = mob:Strike(spec)

				if data.Leapt or data.Stepping then
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
		mob:Unface()

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
