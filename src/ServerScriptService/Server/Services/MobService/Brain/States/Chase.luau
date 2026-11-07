local Attacks = require("../../Combat/Attacks")
local Path = require("../../Path")

local REFRESH = 0.2

local function backOffPoint(mob, target: Vector3, distance: number): Vector3
	local offset = mob.Root.Position - target
	local away = Vector3.new(offset.X, 0, offset.Z)

	if away.Magnitude <= 1e-3 then
		away = -mob.Root.CFrame.LookVector
	end

	return target + away.Unit * distance
end

local function backOff(mob, spec)
	local animation = spec.back_off and spec.back_off.animation

	mob:Burst(Attacks.BackOffSpeed(mob, spec))

	if animation then
		mob.Animation:PlayAction(animation)
		Attacks.Shot(mob, spec.back_off.visual)
	end
end

return {
	Update = function(mob, data)
		local root = mob:TargetRoot()
		if not root then return end

		local distance = mob:TargetDistance()
		local spec = Attacks.Spec(mob, Attacks.NextIndex(mob))
		local now = os.clock()

		if spec.min_range and distance < spec.min_range then
			mob:Face(root.Position)

			if not data.BackingOff then
				data.BackingOff = true
				backOff(mob, spec)
			end

			if data.MovedAt and now - data.MovedAt < REFRESH then return end

			data.MovedAt = now
			mob:MoveTo(backOffPoint(mob, root.Position, Attacks.StandOff(spec)), Attacks.BackOffSpeed(mob, spec))
			return
		end

		data.BackingOff = nil

		if distance <= spec.range then
			data.MovedAt = nil
			Path.Reached(mob)
			mob:Stop()
			mob:Face(root.Position)
			return
		end

		mob:Unface()

		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		local lead = math.min(mob:Setting("chase_lead"), distance / math.max(mob:Setting("run_speed"), 1))
		local waypoint = Path.Steer(mob, root.Position, mob:GetTarget())

		data.MovedAt = now
		mob:MoveTo(waypoint or mob:EngagePoint(mob:LeadPoint(lead), Attacks.StandOff(spec)), "run_speed")
	end,

	Exit = function(mob)
		mob:Stop()
		mob:Unface()
		Path.Drop(mob)
	end,
}
