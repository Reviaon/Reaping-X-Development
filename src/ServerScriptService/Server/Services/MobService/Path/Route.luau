local Config = require("./Config")
local Geometry = require("./Geometry")

local Route = {}

function Route.Clear(nav)
	nav.Waypoints = nil
	nav.Index = nil
	nav.Goal = nil
end

function Route.Adopt(nav, waypoints: { PathWaypoint }, goal: Vector3)
	if #waypoints < 2 then
		Route.Clear(nav)
		return
	end

	nav.Waypoints = waypoints
	nav.Index = 2
	nav.Goal = goal
end

function Route.Follow(nav, mob, position: Vector3, settings): (Vector3?, boolean)
	local waypoints = nav.Waypoints
	local reach = math.max(settings.waypoint_reach, mob.Body.Radius + Config.WaypointMargin)
	local index = nav.Index

	while index <= #waypoints and Geometry.Planar(waypoints[index].Position, position) <= reach do
		index += 1
	end

	local advanced = index ~= nav.Index
	nav.Index = index

	if index > #waypoints then
		Route.Clear(nav)
		return nil, advanced
	end

	return waypoints[index].Position, advanced
end

function Route.End(nav): Vector3?
	local waypoints = nav.Waypoints
	return if waypoints then waypoints[#waypoints].Position else nil
end

return Route
