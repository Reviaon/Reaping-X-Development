local Attacks = require("../../Combat/Attacks")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FALLBACK_LENGTH = 1

local function settingsOf(mob): MobTypes.Alert
	return mob.Config.alert
end

local function length(data, alert: MobTypes.Alert): number
	if alert.hold then return alert.hold end

	local track = data.Track
	return if track and track.Length > 0 then track.Length / (alert.speed or 1) else FALLBACK_LENGTH
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
		local root = mob:TargetRoot()

		if root then
			mob:Face(root.Position)
		end

		if elapsed >= length(data, settingsOf(mob)) then
			data.Done = true
		end
	end,

	Exit = function(mob, data)
		mob:Unface()

		if not data.Done then
			mob.Animation:Stop(settingsOf(mob).animation)
		end
	end,
}
