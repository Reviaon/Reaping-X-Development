--[[@
	**Follow**: a passive bird tags along behind the player it is visiting for a moment (`greet`)
	- **On foot or on the wing:** the visit rolls `greet.fly_chance`; flying, it lifts to `greet.follow_altitude` and keeps up at `flight.speed`
	- **On foot** it walks, running (`run_speed`, `Ground Run`) when it falls more than `CatchUp` studs behind
	- **Spacing:** it keeps `greet.follow_distance` studs back, stopping to watch them when it is close enough
	- **Ends** when the visit's follow time runs out (`Conditions/Alarm/Visiting`)
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../../../Senses/Perception")

local REFRESH = 0.2
local CATCH_UP = 6
local FLAT = Vector3.new(1, 0, 1)

local function settingsOf(mob): MobTypes.Greet
	return mob.Config.greet
end

return {
	Enter = function(mob, data)
		local greet = settingsOf(mob)
		local visit = mob.Blackboard.Visit

		data.Flying = visit ~= nil and visit.Flying == true and mob.Config.flight ~= nil
		mob.Altitude = if data.Flying then greet.follow_altitude else 0
		mob:Unface()
	end,

	Update = function(mob, data)
		local greet = settingsOf(mob)
		local root = Perception.RootOf(mob.Blackboard.Companion)
		local now = os.clock()

		if not root then
			mob:Stop()
			return
		end

		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now

		local offset = (mob.Root.Position - root.Position) * FLAT
		local distance = offset.Magnitude

		if distance <= greet.follow_distance then
			mob:Stop()
			mob:Face(root.Position)
			return
		end

		mob:Unface()

		local speed = if data.Flying then mob.Config.flight.speed
			elseif distance > greet.follow_distance + CATCH_UP then "run_speed"
			else "walk_speed"

		mob:MoveTo(root.Position + offset.Unit * greet.follow_distance, speed)
	end,

	Exit = function(mob)
		mob:Unface()
		mob:Stop()
	end,
}
