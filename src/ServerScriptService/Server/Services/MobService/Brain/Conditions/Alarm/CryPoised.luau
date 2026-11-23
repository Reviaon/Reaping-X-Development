local Flight = require("../../../Body/Flight")

return function(mob)
	local cry = mob.Config.cry
	if not cry then return false end

	return (cry.air ~= nil) == Flight.Airborne(mob)
end
