--[[@
	**Flight**: after the first cry it lifts off and skims round its target, low over the ground
	- **Climb and descent** are studs/s of lift; it lands with `land` once the lift is down to `land_lift`
	- **Circling:** `radius` studs round the target, aiming `step` degrees ahead on the ring each think
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local flight: MobTypes.Flight = {
	altitude = 2.5, --@ Studs above standing: its body flies at a player's head height, low enough for its wingbeat to kick up dust
	climb = 8,
	descent = 6,
	radius = 20,
	step = 35,
	speed = 16, --@ Circling speed
	pace = 12, --@ Studs/s the flight clips play at 1x: at `speed` 16 `Fly Forward` beats 1.33x, and it stays on `Fly Forward` until twice this
	land = "Land",
	land_lift = 2.5, --@ Studs of lift left when `Land` starts: from cruising height, so at `descent` it touches down on the clip's `land` frame (0.42s)
}

return flight
