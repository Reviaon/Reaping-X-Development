return {
	Enter = function(mob)
		mob:Halt()
	end,

	Exit = function(mob)
		mob:Resume()
	end,
}
