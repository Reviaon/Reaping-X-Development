local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FLAT = Vector3.new(1, 0, 1)

local random = Random.new()

local function settingsOf(mob): MobTypes.Flight
	return mob.Config.flight
end

local function ring(mob, centre: Vector3, flight: MobTypes.Flight, side: number): Vector3
	local offset = (mob.Root.Position - centre) * FLAT
	local angle = if offset.Magnitude > 1e-3 then math.atan2(offset.Z, offset.X) else random:NextNumber(0, math.pi * 2)
	local ahead = angle + side * math.rad(flight.step)

	return centre + Vector3.new(math.cos(ahead), 0, math.sin(ahead)) * flight.radius
end

return {
	Enter = function(mob, data)
		data.Side = if random:NextNumber() < 0.5 then -1 else 1
		mob:Unface()
	end,

	Update = function(mob, data)
		local flight = settingsOf(mob)
		local root = mob:TargetRoot()

		mob.Altitude = flight.altitude

		if not root then
			mob:Stop()
			return
		end

		mob:MoveTo(ring(mob, root.Position, flight, data.Side), flight.speed)
	end,

	Exit = function(mob)
		mob:Stop()
	end,
}
