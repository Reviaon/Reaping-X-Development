--[[@
	**Startle**: swing at it, or shoot near it, and it flies off; only a hit that lands sets off its alarm
	- **Spooked by** a swing within `range` studs, or a shot passing within `near` studs
	- **Flies off** up to `altitude`, away from the attacker at `speed`, for `duration` seconds, then goes back to being friendly (its next visit waits out `greet.cooldown`)
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local startle: MobTypes.Startle = {
	range = 14,
	near = 5,
	duration = { 2.5, 3.5 },
	altitude = 24,
	speed = 26,
	distance = 30,
}

return startle
