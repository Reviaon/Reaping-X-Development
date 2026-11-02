local REFRESH = 0.25
local ARRIVE_DISTANCE = 2
local INSIDE_RATIO = 0.8
local BAND_ENTER_RATIO = 1.15
local BAND_EXIT_RATIO = 1.4
local CATCH_UP_RATIO = 1.5
local MODE_HOLD = 0.75
local REPOSITION_ARRIVE = 6
local REPOSITION_TIMEOUT = 4

local random = Random.new()

local function orbitAngle(mob, center: Vector3, lead: number): number
	if mob.Team then
		return mob.Team:OrbitAngle(mob, center, lead)
	end

	local offset = mob.Root.Position - center
	return math.atan2(offset.Z, offset.X) + lead
end

local function ringPoint(center: Vector3, angle: number, radius: number): Vector3
	return center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
end

local function backOutPoint(mob, center: Vector3, radius: number): Vector3
	local offset = mob.Root.Position - center
	local outward = Vector3.new(offset.X, 0, offset.Z)

	if outward.Magnitude <= 0 then
		outward = -mob.Root.CFrame.LookVector
	end

	return center + outward.Unit * radius
end

local function setFacing(data, facing: boolean)
	if data.Facing == facing then return end

	local now = os.clock()
	if data.SwitchedAt and now - data.SwitchedAt < MODE_HOLD then return end

	data.Facing = facing
	data.SwitchedAt = now
end

local function angleAround(mob, center: Vector3): number
	local offset = mob.Root.Position - center
	return math.atan2(offset.Z, offset.X)
end

local function chooseReposition(mob, data, center: Vector3)
	local pack = mob.Config.pack
	local chance = pack.reposition_chance or 0

	if mob:DistanceTo(center) >= pack.orbit_radius * INSIDE_RATIO then return end
	if random:NextNumber() >= chance then return end

	local arc = pack.reposition_arc or { 90, 150 }
	local swing = math.rad(random:NextNumber(arc[1], arc[2])) * (if random:NextNumber() < 0.5 then -1 else 1)

	data.Reposition = {
		Angle = angleAround(mob, center) + swing,
		Until = os.clock() + REPOSITION_TIMEOUT,
	}
end

local function repositionPoint(mob, data, center: Vector3): Vector3?
	local reposition = data.Reposition
	if not reposition then return nil end

	local point = ringPoint(center, reposition.Angle, mob.Config.pack.orbit_radius)

	if mob:DistanceTo(point) <= REPOSITION_ARRIVE or os.clock() >= reposition.Until then
		data.Reposition = nil
		return nil
	end

	return point
end

local function plan(mob, data, center: Vector3)
	local pack = mob.Config.pack
	local radius = pack.orbit_radius
	local fromCenter = mob:DistanceTo(center)
	local sprintTo = repositionPoint(mob, data, center)

	if sprintTo then
		data.Facing = false
		data.SwitchedAt = os.clock()
		return sprintTo, "run_speed"
	end

	if fromCenter < radius * INSIDE_RATIO then
		setFacing(data, true)
		return backOutPoint(mob, center, radius), pack.retreat_speed or "walk_speed"
	end

	local edge = radius * (if data.Facing then BAND_EXIT_RATIO else BAND_ENTER_RATIO)
	setFacing(data, fromCenter < edge)

	local point = ringPoint(center, orbitAngle(mob, center, pack.orbit_drift), radius)

	if not data.Facing and fromCenter > radius * CATCH_UP_RATIO then
		return point, "run_speed"
	end

	return point, "walk_speed"
end

return {
	Enter = function(mob, data)
		if mob.Team then
			mob.Team:SetOrbiting(mob, true)
		end

		local root = mob:TargetRoot()

		if root then
			chooseReposition(mob, data, root.Position)
		end
	end,

	Update = function(mob, data)
		local root = mob:TargetRoot()
		if not root then return end

		local center = root.Position
		local point, speed = plan(mob, data, center)

		if data.Facing then
			mob:Face(center)
		else
			mob:Unface()
		end

		if mob:DistanceTo(point) <= ARRIVE_DISTANCE then
			data.MovedAt = nil
			mob:Stop()
			return
		end

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now
		mob:MoveTo(point, speed)
	end,

	Exit = function(mob)
		if mob.Team then
			mob.Team:SetOrbiting(mob, false)
		end

		mob:Stop()
		mob:Unface()
	end,
}
