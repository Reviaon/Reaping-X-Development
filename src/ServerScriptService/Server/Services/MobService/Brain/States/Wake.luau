local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local function settingsOf(mob): MobTypes.Sleep
	return mob.Config.sleep
end

local function finish(mob, data)
	if data.Done then return end

	local evade: MobTypes.Evade? = mob.Config.evade
	local blackboard = mob.Blackboard

	data.Done = true
	blackboard.Asleep = false
	blackboard.StartledUntil = os.clock() + (if evade then evade.startle else 0)
end

local function awake(track: AnimationTrack?, blend: number): boolean
	if not track or not track.IsPlaying then return true end

	return track.Length > 0 and track.TimePosition >= track.Length - blend
end

return {
	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		mob:Stop()
		mob:Unface()

		if mob:Provoker() then
			finish(mob, data)
			return
		end

		local settings = settingsOf(mob)
		data.Track = mob.Animation:PlayAction(settings.animations.wake, settings.wake_speed)
	end,

	Update = function(mob, data)
		if data.Done then return end

		if mob:Provoker() or awake(data.Track, settingsOf(mob).blend) then
			finish(mob, data)
		end
	end,

	Exit = function(mob, data)
		finish(mob, data)
		mob.Animation:Stop(settingsOf(mob).animations.wake)
	end,
}
