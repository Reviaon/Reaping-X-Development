local REISSUE = 4

return {
	Enter = function(mob, data)
		data.IssuedAt = os.clock()
		mob:MoveTo(mob.Home, "walk_speed")
	end,

	Update = function(mob, data)
		if mob:HomeDistance() <= mob:Setting("home_radius") then
			mob.Blackboard.Returning = false
			mob:Stop()
			return
		end

		local now = os.clock()

		if now - data.IssuedAt >= REISSUE then
			data.IssuedAt = now
			mob:MoveTo(mob.Home, "walk_speed")
		end
	end,

	Exit = function(mob)
		mob:Stop()
	end,
}
