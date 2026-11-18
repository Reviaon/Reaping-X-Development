--[[@
	**Gnaw**: the pack huddles round a player left ragdolled for a while and chews on them
	- **When:** its target is ragdolled with at least `remaining` seconds left, not held in a scene or flying from a throw
	- **Huddle:** up to `gnawers` packmates close in from where they stand, so they ring the body, and loop `animation`
	  - Each loop's `marker` chips `damage` off the victim; no limb is ever taken
	- **Scatter:** the moment the victim gets up, every gnawer hops out `scatter.distance` studs, fanned by up to `scatter.spread` degrees, and the fight starts over
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local gnaw: MobTypes.Gnaw = {
	animation = "Eat", --@ Looped
	visual = "Eat", --@ WolfVisuals timeline per loop
	marker = "RemoveLimb", --@ The bite frame of EatingLoop
	damage = 4, --@ Per bite, per wolf
	remaining = 1.5, --@ Least seconds of ragdoll left to commit to a huddle
	distance = 10, --@ Studs from its root to the torso; the snout reaches the body
	gnawers = 4, --@ Most wolves on one body
	speed = "run_speed",
	scatter = {
		distance = 26, --@ Studs out from the body
		spread = 35, --@ Degrees either side of straight out
	},
}

return gnaw
