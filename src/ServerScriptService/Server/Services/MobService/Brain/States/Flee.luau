local Perception = require("../../Senses/Perception")

local REFRESH = 0.3

local function awayPoint(mob, threat: BasePart?, distance: number): Vector3
	local position = mob.Root.Position
	local away = if threat then position - threat.Position else -mob.Root.CFrame.LookVector
	away = Vector3.new(away.X, 0, away.Z)

	if away.Magnitude < 1e-3 then
		away = -mob.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end

	return position + away.Unit * distance
end

return {
	Enter = function(mob, data)
		data.Threat = mob:GetTarget() or mob:Provoker()

		if mob.Team then
			mob.Team:Engage(mob, false)
		end

		mob:SetTarget(nil)
		mob:Calm()
		mob:Unface()
	end,

	Update = function(mob, data)
		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		local flee = mob.Config.rally.flee

		data.MovedAt = now
		mob:MoveTo(awayPoint(mob, Perception.RootOf(data.Threat), flee.distance), flee.speed)
	end,

	Exit = function(mob)
		mob:Stop()
		mob.Blackboard.Returning = true
		mob.Blackboard.Retreating = true
	end,
}
