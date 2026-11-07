local Path = require("../../Path")

local random = Random.new()

local REFRESH = 0.25

local function around(center: Vector3, radius: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = radius * math.sqrt(random:NextNumber())

	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

return {
	Enter = function(mob, data)
		local search = mob.Blackboard.Search

		data.Goal = search and search.Position
		data.Arrived = false
		data.MovedAt = nil
		Path.Drop(mob)
	end,

	Update = function(mob, data)
		local search = mob.Blackboard.Search
		if not search or not data.Goal then return end

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now

		if mob:DistanceTo(data.Goal) <= mob.Body.Radius + mob:Setting("home_radius") then
			data.Arrived = true
			data.Goal = around(search.Position, mob.Config.search.radius)
		end

		mob:MoveTo(Path.Steer(mob, data.Goal) or data.Goal, if data.Arrived then "walk_speed" else "run_speed")
	end,

	Done = function(mob)
		return mob.Blackboard.Search == nil
	end,

	Exit = function(mob)
		mob:Stop()
		Path.Drop(mob)
	end,
}
