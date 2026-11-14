--[[@
	**Evade**: running from predators and keeping away from them
	- **Predators:** any player it notices (sight or hearing), whoever hurt it, and the mobs named in `predators`
	- **Escape line:** straight away from them all, swung through `fan` until a line is clear of walls
	- **Keeping away:** inside `range` it runs until all are past `safe`; inside `watch` it then stops and watches the nearest instead of heading home
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local evade: MobTypes.Evade = {
	range = 30, --@ Studs a noticed predator sets it running from
	safe = 50, --@ Studs every predator must be past before it stops
	watch = 65, --@ Studs inside which it stays put watching the nearest instead of heading home
	distance = 22, --@ Studs ahead it aims each refresh
	speed = "run_speed",
	refresh = 0.3, --@ Seconds between re-aims
	startle = 2.5, --@ Seconds it keeps running from what woke or hurt it, however far away that is
	fan = { 0, 35, -35, 70, -70, 105, -105 }, --@ Degrees off straight-away it tries, in order
	predators = { "Wolf" }, --@ Mob names it runs from as well as players
}

return evade
