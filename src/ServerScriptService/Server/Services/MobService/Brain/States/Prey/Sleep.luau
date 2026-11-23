local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local function settingsOf(mob): MobTypes.Sleep
	return mob.Config.sleep
end

local function settling(track: AnimationTrack?, blend: number): boolean
	if not track or not track.IsPlaying then return false end

	return track.Length == 0 or track.TimePosition < track.Length - blend
end

return {
	Enter = function(mob, data)
		local blackboard = mob.Blackboard

		mob:Stop()
		mob:Unface()

		if blackboard.Asleep then return end

		blackboard.Asleep = true
		data.Lying = mob.Animation:PlayAction(settingsOf(mob).animations.lie)
	end,

	Update = function(mob, data)
		local settings = settingsOf(mob)

		if settling(data.Lying, settings.blend) then return end

		data.Lying = nil
		mob.Animation:PlayLoop(settings.animations.loop)
	end,

	Exit = function(mob)
		local animations = settingsOf(mob).animations

		mob.Animation:Stop(animations.lie)
		mob.Animation:Stop(animations.loop)
	end,
}
