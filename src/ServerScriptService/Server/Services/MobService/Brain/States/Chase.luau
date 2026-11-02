local Combat = require("../../Combat")

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

	mob:Burst(Combat.BackOffSpeed(mob, spec))

	if animation then
		mob.Animation:PlayAction(animation)
		Combat.Shot(mob, spec.back_off.visual)
	end
end

return {
	Update = function(mob, data)
		local root = mob:TargetRoot()
		if not root then return end

		local distance = mob:TargetDistance()
		local spec = Combat.Spec(mob, Combat.NextIndex(mob))
		local now = os.clock()

		if spec.min_range and distance < spec.min_range then
			mob:Face(root.Position)

			if not data.BackingOff then
				data.BackingOff = true
				backOff(mob, spec)
			end

			if data.MovedAt and now - data.MovedAt < REFRESH then return end

			data.MovedAt = now
			mob:MoveTo(backOffPoint(mob, root.Position, Combat.StandOff(spec)), Combat.BackOffSpeed(mob, spec))
			return
		end

		data.BackingOff = nil

		if distance <= spec.range then
			data.MovedAt = nil
			mob:Stop()
			mob:Face(root.Position)
			return
		end

		mob:Unface()

		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		local lead = math.min(mob:Setting("chase_lead"), distance / math.max(mob:Setting("run_speed"), 1))

		data.MovedAt = now
		mob:MoveTo(mob:EngagePoint(mob:LeadPoint(lead), Combat.StandOff(spec)), "run_speed")
	end,

	Exit = function(mob)
		mob:Stop()
		mob:Unface()
	end,
}
