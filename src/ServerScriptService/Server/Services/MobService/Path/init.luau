local Geometry = require("@self/Geometry")
local Probe = require("@self/Probe")
local Route = require("@self/Route")
local Progress = require("@self/Progress")
local Queue = require("@self/Queue")

local Path = {}

local function navigator(mob)
	local nav = mob.Navigator

	if not nav then
		nav = {
			StuckSince = 0,
			NextRequestAt = 0,
			Reach = setmetatable({}, { __mode = "k" }),
		}
		mob.Navigator = nav
	end

	return nav
end

local function note(mob, nav, target: Model, evidence)
	nav.Reach[target] = evidence

	if mob.Team then
		mob.Team:NoteReach(target, evidence)
	end
end

local function settle(mob, nav, target: Model?)
	return function(status: Enum.PathStatus, waypoints: { PathWaypoint }?, goal: Vector3)
		if waypoints then
			Route.Adopt(nav, waypoints, goal)
		else
			Route.Clear(nav)
		end

		if not target then return end

		if status == Enum.PathStatus.Success then
			note(mob, nav, target, nil)
			return
		end

		local closest = if waypoints then waypoints[#waypoints].Position else mob.Root.Position
		note(mob, nav, target, { Closest = closest, Until = os.clock() + mob.Config.path.recheck })
	end
end

local function request(mob, nav, position: Vector3, goal: Vector3, target: Model?, stuck: boolean, distance: number, settings, now: number)
	if Queue.Busy(nav) or now < nav.NextRequestAt then return end

	nav.NextRequestAt = now + settings.repath
	Progress.Unstick(nav, position, now)

	if target and stuck and Progress.Attempt(nav, target, distance, settings) then
		Progress.Reset(nav)
		Route.Clear(nav)
		note(mob, nav, target, { Closest = position, Until = now + settings.recheck })
		return
	end

	Queue.Request(nav, mob, position, goal, settings, settle(mob, nav, target))
end

function Path.Steer(mob, goal: Vector3, target: Model?): Vector3?
	local settings = mob.Config.path
	if not settings or not mob.Root then return nil end

	local nav = navigator(mob)
	local now = os.clock()
	local position = mob.Root.Position
	local distance = Geometry.Planar(goal, position)
	local stuck = Progress.Stuck(nav, position, now, settings)

	if nav.Waypoints then
		if stuck or Geometry.Planar(goal, nav.Goal) > settings.retarget then
			request(mob, nav, position, goal, target, stuck, distance, settings, now)
		end

		local waypoint, advanced = Route.Follow(nav, mob, position, settings)

		if advanced and waypoint and Probe.Clear(mob, goal, distance, settings) then
			Route.Clear(nav)
			return nil
		end

		return waypoint
	end

	local blocked = not stuck and distance >= settings.min_distance and not Probe.Lane(nav, mob, goal, distance, settings, now)

	if stuck or blocked then
		request(mob, nav, position, goal, target, stuck, distance, settings, now)
	end

	return nil
end

function Path.Unreachable(mob, target: Model?)
	if not target or not mob.Config.path then return nil end

	local now = os.clock()
	local nav = mob.Navigator
	local own = nav and nav.Reach[target]

	if own then
		if now < own.Until then return own end
		nav.Reach[target] = nil
	end

	return if mob.Team then mob.Team:ReachOf(target, now) else nil
end

function Path.Retest(mob, target: Model, goal: Vector3)
	local settings = mob.Config.path
	if not settings or not mob.Root then return end

	local nav = navigator(mob)
	local evidence = Path.Unreachable(mob, target)
	local now = os.clock()

	if not evidence or evidence.Retesting or evidence.Until - now > settings.repath then return end
	if Queue.Busy(nav) or now < nav.NextRequestAt then return end

	evidence.Retesting = true
	nav.NextRequestAt = now + settings.repath
	Queue.Request(nav, mob, mob.Root.Position, goal, settings, function(status, waypoints)
		if status == Enum.PathStatus.Success then
			note(mob, nav, target, nil)
			return
		end

		local closest = if waypoints then waypoints[#waypoints].Position else evidence.Closest
		note(mob, nav, target, { Closest = closest, Until = os.clock() + settings.recheck })
	end)
end

function Path.LaneClear(mob, goal: Vector3): boolean
	local settings = mob.Config.path
	if not settings or not mob.Root then return true end

	local distance = Geometry.Planar(goal, mob.Root.Position)

	return distance < settings.min_distance or Probe.Clear(mob, goal, distance, settings)
end

function Path.Reached(mob)
	local nav = mob.Navigator

	if nav then
		Progress.Reset(nav)
	end
end

function Path.Drop(mob)
	local nav = mob.Navigator

	if nav then
		Route.Clear(nav)

		if mob.Root then
			Progress.Unstick(nav, mob.Root.Position, os.clock())
		end
	end
end

function Path.State(mob): string
	local nav = mob.Navigator
	if not nav then return "direct" end
	if Queue.Busy(nav) then return "computing" end

	return if nav.Waypoints then `following {nav.Index}/{#nav.Waypoints}` else "direct"
end

function Path.Describe(mob): { string }
	local settings = mob.Config.path
	if not settings then return { "no path config" } end

	local nav = mob.Navigator
	local now = os.clock()
	local lines = { Path.State(mob) }

	if not nav then return lines end

	if nav.LaneAt then
		table.insert(lines, string.format("lane %s %.1fs ago", if nav.LaneClear then "clear" else "blocked", now - nav.LaneAt))
	end

	local still = now - nav.StuckSince

	if mob.Moving and still >= settings.stuck_time then
		table.insert(lines, string.format("stuck %.1fs", still))
	end

	if nav.Attempts and nav.Attempts.Count > 0 then
		table.insert(lines, `stuck replans {nav.Attempts.Count}/{settings.attempts} on {nav.Attempts.Target.Name}`)
	end

	local target = mob:GetTarget()
	local evidence = Path.Unreachable(mob, target)

	if evidence then
		local source = if nav.Reach[target] == evidence then "own" else "team"
		local retest = if evidence.Retesting then ", retesting" else ""

		table.insert(lines, string.format("%s unreachable (%s) %.1fs left, closest %.1f studs away%s", target.Name, source, evidence.Until - now, Geometry.Planar(evidence.Closest, mob.Root.Position), retest))
	end

	return lines
end

Path.Backlog = Queue.Backlog

return Path
