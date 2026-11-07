local Path = require("../../Path")

local REFRESH = 0.25

return {
	Enter = function(mob, data)
		data.MovedAt = nil
		Path.Drop(mob)
	end,

	Update = function(mob, data)
		local blackboard = mob.Blackboard
		local distance = mob:HomeDistance()

		if distance <= mob:Setting("home_radius") then
			blackboard.Returning = false
			blackboard.Retreating = false
			mob:Stop()
			return
		end

		if blackboard.Retreating and distance <= mob:Setting("leash_range") then
			blackboard.Retreating = false
		end

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now
		mob:MoveTo(Path.Steer(mob, mob.Home) or mob.Home, if distance > mob:Setting("return_run") then "run_speed" else "walk_speed")
	end,

	Exit = function(mob)
		mob:Stop()
		Path.Drop(mob)
	end,
}
