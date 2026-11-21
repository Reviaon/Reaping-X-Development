local Attacks = require("../../Combat/Attacks")
local Call = require("../../Combat/Call")
local Cower = require("../../Combat/Cower")
local Flight = require("../../Body/Flight")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FALLBACK_LENGTH = 1
local CRYING = "IsCrying"

local random = Random.new()

local function settingsOf(mob): MobTypes.Cry
	return mob.Config.cry
end

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

local function lengthOf(track: AnimationTrack?): number
	return if track and track.Length > 0 then track.Length else FALLBACK_LENGTH
end

local function play(mob, data, phase: string, key: string, looped: boolean?)
	if data.Key then
		mob.Animation:Stop(data.Key)
	end

	data.Phase = phase
	data.Key = key
	data.At = os.clock()
	data.Track = if looped then mob.Animation:PlayLoop(key) else mob.Animation:PlayAction(key)
end

local function call(mob, data, cry: MobTypes.Cry)
	if data.Called then return end

	data.Called = true

	local target = mob:GetTarget()

	if target then
		Call.Provoke(mob, target, cry.radius, cry.kinds)
	end

	if cry.stun then
		Cower.Stun(mob, cry.stun)
	end

	mob.Model:SetAttribute(CRYING, true)
	Attacks.Shot(mob, cry.shake)
end

local function quiet(mob)
	mob.Model:SetAttribute(CRYING, nil)
end

return {
	Armored = true,

	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		local cry = settingsOf(mob)

		mob:Stop()
		mob.Blackboard.CryAt = os.clock() + roll(cry.every)
		data.Airborne = cry.air ~= nil and Flight.Airborne(mob)

		if data.Airborne then
			data.Hold = roll(cry.air_hold or cry.hold)
			play(mob, data, "Loop", cry.air :: string, true)
			call(mob, data, cry)
		else
			data.Hold = roll(cry.hold)
			play(mob, data, "Start", cry.start)
		end
	end,

	Update = function(mob, data)
		local cry = settingsOf(mob)
		local root = mob:TargetRoot()
		local now = os.clock()
		local elapsed = now - data.At

		if root then
			mob:Face(root.Position)
		end

		if data.Phase == "Start" then
			if elapsed >= cry.call then
				call(mob, data, cry)
			end

			if elapsed >= lengthOf(data.Track) then
				play(mob, data, "Loop", cry.loop, true)
			end
		elseif data.Phase == "Loop" then
			if elapsed < data.Hold then return end

			quiet(mob)

			if data.Airborne then
				data.Done = true
			else
				play(mob, data, "Finish", cry.finish)
			end
		elseif data.Phase == "Finish" and elapsed >= lengthOf(data.Track) then
			data.Done = true
		end
	end,

	Exit = function(mob, data)
		mob:Unface()
		quiet(mob)

		if data.Key and (not data.Done or data.Phase == "Loop") then
			mob.Animation:Stop(data.Key)
		end
	end,
}
