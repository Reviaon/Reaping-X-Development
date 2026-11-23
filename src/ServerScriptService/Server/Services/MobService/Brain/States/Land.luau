local Flight = require("../../Body/Flight")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FALLBACK_LENGTH = 1
local LAND_FADE = 0.25

local function settingsOf(mob): MobTypes.Flight
	return mob.Config.flight
end

return {
	Locked = function(_, data)
		return data.Track ~= nil and not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		mob.Altitude = 0
		mob:Stop()
		mob:Unface()

		if not Flight.Airborne(mob) then
			data.Done = true
		end
	end,

	Update = function(mob, data)
		if data.Done then return end

		local flight = settingsOf(mob)
		local lift = Flight.Lift(mob)

		if not data.Track and lift <= flight.land_lift then
			data.At = os.clock()
			data.Track = mob.Animation:PlayAction(flight.land) or false
		end

		if data.Track == nil then return end

		local length = if data.Track and data.Track.Length > 0 then data.Track.Length else FALLBACK_LENGTH
		local settle = math.min(flight.land_settle or length, length)

		if os.clock() - data.At >= settle and lift <= Flight.Settings.Airborne then
			data.Done = true
		end
	end,

	Exit = function(mob, data)
		if not mob:GetTarget() then
			mob.Blackboard.CryAt = nil
		end

		if data.Track then
			mob.Animation:Stop(settingsOf(mob).land, LAND_FADE)
		end
	end,
}
