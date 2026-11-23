local Flight = require("../../../Body/Flight")

return function(mob)
	local cry = mob.Config.cry
	return cry ~= nil and cry ~= false and cry.air == nil and Flight.Airborne(mob)
end
