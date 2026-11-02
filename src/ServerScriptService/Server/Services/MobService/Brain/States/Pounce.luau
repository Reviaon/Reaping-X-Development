return {
	Enter = function(mob, data)
		local pounce = mob.Config.pounce
		local root = mob:TargetRoot()

		data.Pounce = pounce
		mob.Blackboard.NextPounceAt = os.clock() + pounce.windup + pounce.duration + pounce.cooldown
		mob:Stop()

		if root then
			mob:Face(root.Position)
		end

		if pounce.animation then
			mob.Animation:PlayAction(pounce.animation)
		end
	end,

	Update = function(mob, data, _, elapsed)
		local pounce = data.Pounce
		local root = mob:TargetRoot()

		if not root then
			data.Done = true
			return
		end

		if elapsed < pounce.windup then
			mob:Face(root.Position)
			return
		end

		if not data.Launched then
			local aim = mob:LeadPoint(pounce.lead)

			data.Launched = true
			mob:Face(aim)
			mob:MoveTo(mob:EngagePoint(aim), pounce.speed)
			mob:Burst(pounce.speed)
		end

		if elapsed >= pounce.windup + pounce.duration or mob:TargetDistance() <= mob:Setting("attack_range") then
			data.Done = true
		end
	end,

	Locked = function(_, data)
		return not data.Done
	end,

	Exit = function(mob, data)
		mob:Unface()

		if not data.Done then
			mob:Stop()
		end
	end,
}
