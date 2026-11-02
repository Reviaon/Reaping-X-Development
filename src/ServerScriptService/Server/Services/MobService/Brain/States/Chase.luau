local REFRESH = 0.2

return {
	Update = function(mob, data)
		local root = mob:TargetRoot()
		if not root then return end

		local distance = mob:TargetDistance()

		if distance <= mob:Setting("attack_range") then
			data.MovedAt = nil
			mob:Stop()
			mob:Face(root.Position)
			return
		end

		local now = os.clock()

		mob:Unface()

		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		local lead = math.min(mob:Setting("chase_lead"), distance / math.max(mob:Setting("run_speed"), 1))

		data.MovedAt = now
		mob:MoveTo(mob:EngagePoint(mob:LeadPoint(lead)), "run_speed")
	end,

	Exit = function(mob)
		mob:Stop()
		mob:Unface()
	end,
}
