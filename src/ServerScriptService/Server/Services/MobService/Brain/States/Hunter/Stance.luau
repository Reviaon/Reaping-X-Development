local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local function settingsOf(mob): MobTypes.Stance
	return mob.Config.stance
end

local function settled(track: AnimationTrack?, blend: number): boolean
	if not track or not track.IsPlaying then return true end

	return track.Length > 0 and track.TimePosition >= track.Length - blend
end

local function faceTarget(mob)
	local target = mob:GetTarget()
	local root = target and target:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		mob:Face(root.Position)
	end
end

local function finish(mob, data)
	if data.Done then return end

	data.Done = true
	mob.Blackboard.Stanced = data.Entering
end

return {
	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		local settings = settingsOf(mob)

		data.Entering = mob.Blackboard.Stanced ~= true
		mob:Stop()

		if data.Entering then
			faceTarget(mob)
			data.Key = settings.enter
			data.Track = mob.Animation:PlayAction(settings.enter, settings.enter_speed)
		else
			mob:Unface()
			data.Key = settings.exit
			data.Track = mob.Animation:PlayAction(settings.exit, settings.exit_speed)
		end
	end,

	Update = function(mob, data)
		if data.Entering then
			faceTarget(mob)
		end

		if settled(data.Track, settingsOf(mob).blend) then
			finish(mob, data)
		end
	end,

	Exit = function(mob, data)
		finish(mob, data)

		if data.Key then
			mob.Animation:Stop(data.Key, settingsOf(mob).blend)
		end
	end,
}
