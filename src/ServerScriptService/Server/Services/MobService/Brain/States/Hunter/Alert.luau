local Attacks = require("../../../Combat/Attacks")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FALLBACK_LENGTH = 1

local random = Random.new()

local function settingsOf(mob): MobTypes.Alert
	return mob.Config.alert
end

local function length(data, alert: MobTypes.Alert): number
	if alert.hold then return alert.hold end

	local track = data.Track
	return if track and track.Length > 0 then track.Length / (alert.speed or 1) else FALLBACK_LENGTH
end

local function roll(range: { number }?): number
	if not range then return FALLBACK_LENGTH end
	return random:NextNumber(range[1], range[2] or range[1])
end

return {
	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		local alert = settingsOf(mob)

		mob.Blackboard.Alerted = mob:GetTarget()
		mob.Blackboard.AlertedAt = os.clock()
		mob:Stop()

		data.Track = mob.Animation:PlayAction(alert.animation, alert.speed)
		Attacks.Shot(mob, alert.visual)
	end,

	Update = function(mob, data, _, elapsed)
		local alert = settingsOf(mob)
		local root = mob:TargetRoot()

		if root then
			mob:Face(root.Position)
		end

		if data.LoopUntil then
			if elapsed >= data.LoopUntil then
				data.Done = true
			end
			return
		end

		if elapsed < length(data, alert) then return end

		if alert.loop then
			data.LoopUntil = elapsed + roll(alert.loop_hold)
			data.Loop = mob.Animation:PlayLoop(alert.loop)
		else
			data.Done = true
		end
	end,

	Exit = function(mob, data)
		local alert = settingsOf(mob)

		mob:Unface()

		if data.Loop and alert.loop then
			mob.Animation:Stop(alert.loop)
		elseif not data.Done then
			mob.Animation:Stop(alert.animation)
		end
	end,
}
