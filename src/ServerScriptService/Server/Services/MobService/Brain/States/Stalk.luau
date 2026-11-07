local Path = require("../../Path")

local REFRESH = 0.25

local function planar(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return {
	Enter = function(mob, data)
		data.MovedAt = nil

		if mob.Team then
			mob.Team:ReleaseSlot(mob)
		end

		Path.Drop(mob)
	end,

	Update = function(mob, data)
		local target = mob:GetTarget()
		local root = mob:TargetRoot()
		local evidence = Path.Unreachable(mob, target)
		if not root or not evidence then return end

		Path.Retest(mob, target, root.Position)

		local arrive = mob.Config.path.waypoint_reach + mob.Body.Radius

		if planar(mob.Root.Position, evidence.Closest) <= arrive then
			data.MovedAt = nil
			mob:Stop()
			mob:Face(root.Position)
			return
		end

		mob:Unface()

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now
		mob:MoveTo(Path.Steer(mob, evidence.Closest) or evidence.Closest, "walk_speed")
	end,

	Exit = function(mob)
		mob:Stop()
		mob:Unface()
		Path.Drop(mob)
	end,
}
