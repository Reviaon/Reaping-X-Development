local HURT_FADE = 0.15

return {
	Enter = function(mob)
		mob:Halt()

		if mob.Model:GetAttribute("InPairScene") then return end

		mob.Blackboard.Staggered = true

		local fight = mob:Fight()

		if fight then
			fight:ReleaseSlot(mob)
		end
	end,

	Exit = function(mob)
		mob:Resume()

		for _, key in mob.Config.hurt_animations or {} do
			mob.Animation:Stop(key, HURT_FADE)
		end
	end,
}
