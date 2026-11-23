local Arc = require("../../../Body/Arc")

local FLAT = Vector3.new(1, 0, 1)
local LIFT_GRACE = 0.25

local function landingOf(mob, pounce): Vector3?
	local root = mob:TargetRoot()
	if not root then return nil end

	return mob:EngagePoint(mob:LeadPoint(pounce.lead), pounce.stop or mob:Setting("attack_range"))
end

local function hop(mob, data)
	local pounce = data.Pounce
	local arc = pounce.arc
	local track = data.Track
	local origin = mob.Root.Position
	local landing = landingOf(mob, pounce)

	if not landing then
		data.Done = true
		return
	end

	local travel = (landing - origin) * FLAT
	local most = (pounce.max_speed or math.huge) * pounce.duration

	if travel.Magnitude > most then
		landing = origin + travel.Unit * most
	end

	Arc.Begin(mob, landing, pounce.duration, arc.height, {
		Home = arc.home,
		Aim = function()
			return landingOf(mob, pounce)
		end,
		OnStep = function()
			if data.Stretched or not track or track.TimePosition < arc.hold then return end

			data.Stretched = true

			local left = Arc.Remaining(mob)

			if left > 1e-3 then
				track:AdjustSpeed(math.max(arc.resume - track.TimePosition, 0) / left)
			end
		end,
		OnLand = function()
			data.Done = true

			if track and pounce.animation then
				mob.Animation:Stop(pounce.animation, pounce.blend)
			end
		end,
	})
end

local function lifted(data, elapsed: number): boolean
	local pounce = data.Pounce
	local track = data.Track

	if track and track.IsPlaying then
		return track.TimePosition >= pounce.windup or elapsed >= pounce.windup + LIFT_GRACE
	end

	return elapsed >= pounce.windup
end

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
			data.Track = mob.Animation:PlayAction(pounce.animation)
		end
	end,

	Update = function(mob, data, _, elapsed)
		local pounce = data.Pounce
		local root = mob:TargetRoot()

		if data.Done then return end

		if not root then
			data.Done = true
			return
		end

		if pounce.arc then
			if not data.Launched and lifted(data, elapsed) then
				data.Launched = true
				hop(mob, data)
			elseif not data.Launched then
				mob:Face(root.Position)
			end

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

		if Arc.Active(mob) then
			Arc.Stop(mob)
		end

		if not data.Done then
			mob:Stop()

			if data.Track and data.Pounce.animation then
				mob.Animation:Stop(data.Pounce.animation)
			end
		end
	end,
}
