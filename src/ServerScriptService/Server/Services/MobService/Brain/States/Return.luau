local PathfindingService = game:GetService("PathfindingService")

local REISSUE = 4
local STUCK_TIME = 1.5
local PROGRESS = 1.5
local REPATH = 4
local WAYPOINT_REACH = 4
local AGENT_HEIGHT = 5

local function planarDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function computePath(mob, data)
	data.Pending = true
	data.PathedAt = os.clock()

	local from, to = mob.Root.Position, mob.Home

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = mob.Body.Radius,
			AgentHeight = AGENT_HEIGHT,
			AgentCanJump = false,
		})

		local ok = pcall(path.ComputeAsync, path, from, to)

		data.Pending = false

		if ok and path.Status == Enum.PathStatus.Success then
			data.Waypoints = path:GetWaypoints()
			data.Index = 2
			data.Leg = nil
		end
	end)
end

local function follow(mob, data): boolean
	local waypoints = data.Waypoints
	if not waypoints then return false end

	while data.Index <= #waypoints and planarDistance(waypoints[data.Index].Position, mob.Root.Position) <= WAYPOINT_REACH do
		data.Index += 1
	end

	if data.Index > #waypoints then
		data.Waypoints = nil
		return false
	end

	if data.Leg ~= data.Index then
		data.Leg = data.Index
		mob:MoveTo(waypoints[data.Index].Position, "walk_speed")
	end

	return true
end

return {
	Enter = function(mob, data)
		local now = os.clock()

		data.IssuedAt = now
		data.Best = mob:HomeDistance()
		data.ProgressAt = now
		mob:MoveTo(mob.Home, "walk_speed")
	end,

	Update = function(mob, data)
		local distance = mob:HomeDistance()

		if distance <= mob:Setting("home_radius") then
			mob.Blackboard.Returning = false
			mob:Stop()
			return
		end

		local now = os.clock()

		if distance < data.Best - PROGRESS then
			data.Best = distance
			data.ProgressAt = now
		end

		local stuck = now - data.ProgressAt >= STUCK_TIME

		if stuck and not data.Pending and now - (data.PathedAt or -math.huge) >= REPATH then
			data.ProgressAt = now
			computePath(mob, data)
		end

		if follow(mob, data) then return end

		if now - data.IssuedAt >= REISSUE then
			data.IssuedAt = now
			mob:MoveTo(mob.Home, "walk_speed")
		end
	end,

	Exit = function(mob)
		mob:Stop()
	end,
}
