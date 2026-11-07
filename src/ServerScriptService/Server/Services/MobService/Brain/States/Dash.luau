local Attacks = require("../../Combat/Attacks")
local Awareness = require("../../Senses/Awareness")

local IFRAMES = "IFrames"
local UP = Vector3.new(0, 1, 0)
local MIN_TRAVEL = 2.5
local ARRIVE_DISTANCE = 1.5
local OVERRUN = 0.25
local DODGE_RETREAT = 0.5
local ENGAGE_DEPTH = 0.8
local BACK_ENOUGH = 0.85
local AROUND_ENOUGH = math.rad(18)
local REANIMATE = 0.5

local random = Random.new()

local function planar(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function lookOf(root: BasePart): Vector3?
	local look = planar(root.CFrame.LookVector)
	return if look.Magnitude > 1e-3 then look.Unit else nil
end

local function angleFrom(look: Vector3, offset: Vector3): number
	return math.atan2(look:Cross(offset).Y, look:Dot(offset))
end

local function around(center: Vector3, look: Vector3, angle: number, radius: number): Vector3
	return center + CFrame.fromAxisAngle(UP, angle):VectorToWorldSpace(look) * radius
end

local function animationFor(mob, dash, direction: Vector3): string?
	if direction.Magnitude < 1e-3 then return nil end

	local relative = mob.Root.CFrame:VectorToObjectSpace(direction.Unit)
	local forward, side = -relative.Z, relative.X
	local animations = dash.animations or {}

	if forward >= math.abs(side) then return nil end
	if -forward >= math.abs(side) then return animations.Back end

	return if side > 0 then animations.Right else animations.Left
end

local function animate(mob, dash, data, direction: Vector3, now: number)
	local animation = animationFor(mob, dash, direction)

	if animation and (animation ~= data.Animation or now - (data.AnimatedAt or 0) >= REANIMATE) then
		data.Animation = animation
		data.AnimatedAt = now
		mob.Animation:PlayAction(animation, dash.playback)
		Attacks.Shot(mob, dash.visual, dash.playback)
	end
end

local function dodgePoint(mob, dodge, from: Vector3): Vector3
	local position = mob.Root.Position
	local away = planar(position - from)

	if away.Magnitude < 1e-3 then
		away = -planar(mob.Root.CFrame.LookVector)
	end

	away = away.Unit

	local side = Vector3.new(-away.Z, 0, away.X) * (if random:NextNumber() < 0.5 then -1 else 1)

	return position + (side + away * DODGE_RETREAT).Unit * dodge.distance
end

local function regroupPoint(mob, root: BasePart): Vector3
	local pack = mob.Config.pack

	if not pack or not mob.Team or mob.Team:IsAttacker(mob) then
		return mob:EngagePoint(root.Position, mob.Config.attack.reach * ENGAGE_DEPTH)
	end

	local outward = planar(mob.Root.Position - root.Position)

	if outward.Magnitude < 1e-3 then
		outward = -planar(mob.Root.CFrame.LookVector)
	end

	return root.Position + outward.Unit * pack.orbit_radius
end

local function hop(mob, dash, data, point: Vector3?): boolean
	local travel = point and planar(point - mob.Root.Position)
	if not point or travel.Magnitude < MIN_TRAVEL then return false end

	local root = mob:TargetRoot()

	data.Point = point
	data.Until = travel.Magnitude / dash.speed + OVERRUN

	if root then
		mob:Face(root.Position)
	end

	mob:MoveTo(point, dash.speed)
	mob:Burst(dash.speed)
	animate(mob, dash, data, travel.Unit, os.clock())

	return true
end

local function startFlank(mob, dash, data): boolean
	local flank = dash.flank
	local root = mob:TargetRoot()
	local look = root and lookOf(root)
	if not look then return false end

	local radius = flank.radius or mob:Setting("attack_range")
	local run = random:NextNumber() < (flank.run_chance or 0)
	local offset = planar(mob.Root.Position - root.Position)
	local sign = if angleFrom(look, offset) >= 0 then 1 else -1

	data.Flank = {
		Run = run,
		Radius = if run then radius * (flank.run_radius or 1) else radius,
		Goal = math.rad(random:NextNumber(flank.angle[1], flank.angle[2])) * sign,
		Step = math.rad(flank.step or 40),
		Until = os.clock() + (flank.timeout or 2),
		Phase = if offset.Magnitude < radius * BACK_ENOUGH then "Back" else "Around",
	}

	return true
end

local function stepFlank(mob, dash, data): boolean
	local flank = data.Flank
	local root = mob:TargetRoot()
	local look = root and lookOf(root)
	local now = os.clock()

	if not look or now >= flank.Until then return true end

	local center = root.Position
	local offset = planar(mob.Root.Position - center)
	local speed = if flank.Run then mob:Setting("run_speed") else dash.speed

	if flank.Phase == "Back" then
		if offset.Magnitude >= flank.Radius * BACK_ENOUGH then
			flank.Phase = "Around"
		else
			local outward = if offset.Magnitude > 1e-3 then offset.Unit else -planar(mob.Root.CFrame.LookVector)
			local point = center + outward * flank.Radius

			mob:Face(center)
			mob:MoveTo(point, dash.speed)
			mob:Burst(dash.speed)
			animate(mob, dash, data, point - mob.Root.Position, now)

			return false
		end
	end

	local angle = angleFrom(look, offset)
	local remaining = flank.Goal - angle

	if math.abs(remaining) <= AROUND_ENOUGH then return true end

	local point = around(center, look, angle + math.clamp(remaining, -flank.Step, flank.Step), flank.Radius)

	if flank.Run then
		mob:Unface()
	else
		mob:Face(center)
		animate(mob, dash, data, point - mob.Root.Position, now)
	end

	mob:MoveTo(point, speed)
	mob:Burst(speed)

	return false
end

return {
	Enter = function(mob, data, args)
		local dash = mob.Config.dash
		local kind = args and args.kind
		local root = mob:TargetRoot()
		local blackboard = mob.Blackboard

		data.Recovery = dash and dash.recovery or 0

		if not dash then
			data.Done = true
			return
		end

		if kind == "flank" then
			blackboard.FlankReadyAt = os.clock() + dash.flank.cooldown

			if not startFlank(mob, dash, data) or stepFlank(mob, dash, data) then
				data.Done = true
			end

			return
		end

		local point

		if kind == "regroup" then
			blackboard.Staggered = nil
			point = root and regroupPoint(mob, root)
		elseif kind == "sidestep" then
			point = Awareness.Sidestep.Point(mob)
		elseif args and args.from and dash.dodge then
			blackboard.Staggered = nil
			point = dodgePoint(mob, dash.dodge, args.from)

			if dash.dodge.iframes then
				mob.Services.StatusService:ApplyStatus(mob.Model, IFRAMES, true, dash.dodge.iframes)
			end
		end

		if not hop(mob, dash, data, point) then
			data.Done = true
		end
	end,

	Update = function(mob, data, _, elapsed)
		if data.Done then return end

		if data.Flank and not data.Landed then
			if stepFlank(mob, mob.Config.dash, data) then
				data.Landed = elapsed
				mob:Stop()
			end
		elseif not data.Landed then
			local root = mob:TargetRoot()

			if root then
				mob:Face(root.Position)
			end

			if elapsed >= data.Until or planar(data.Point - mob.Root.Position).Magnitude <= ARRIVE_DISTANCE then
				data.Landed = elapsed
				mob:Stop()
			end
		end

		if data.Landed and elapsed - data.Landed >= data.Recovery then
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

		if not data.Landed and (data.Point or data.Flank) then
			mob:Stop()
		end
	end,
}
