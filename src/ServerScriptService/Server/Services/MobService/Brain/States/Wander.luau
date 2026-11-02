local random = Random.new()

local ARRIVE_DISTANCE = 2
local MOVE_TIMEOUT = 7

local function pickPoint(mob): Vector3
	local radius = mob:Setting("wander_radius")
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = radius * math.sqrt(random:NextNumber())

	return mob.Home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function stopIdleAction(mob, data)
	if not data.IdleAction then return end

	mob.Animation:Stop(data.IdleAction)
	data.IdleAction = nil
end

local function rest(mob, data)
	local pause = mob:Setting("wander_pause")

	data.Point = nil
	data.ResumeAt = os.clock() + random:NextNumber(pause[1], pause[2])
	mob:Stop()

	local actions = mob.Config.idle_actions

	if actions and #actions > 0 and random:NextNumber() < (mob.Config.idle_action_chance or 0) then
		data.IdleAction = actions[random:NextInteger(1, #actions)]
		mob.Animation:PlayAction(data.IdleAction)
	end
end

return {
	Enter = function(mob, data)
		rest(mob, data)
	end,

	Update = function(mob, data)
		local now = os.clock()

		if data.Point then
			if mob:DistanceTo(data.Point) <= ARRIVE_DISTANCE or now - data.MovedAt >= MOVE_TIMEOUT then
				rest(mob, data)
			end

			return
		end

		if now < data.ResumeAt then return end

		stopIdleAction(mob, data)
		data.Point = pickPoint(mob)
		data.MovedAt = now
		mob:MoveTo(data.Point, "walk_speed")
	end,

	Exit = function(mob, data)
		stopIdleAction(mob, data)
		mob:Stop()
	end,
}
