--[[@
	**Cry**: the alarm, only while it is alarmed (hurt, or one of its kind killed close by)
	- **On the wing:** it takes off first if it is on the ground, hovers on `FlyCry`, then pulls out with `FlyCryEnd`; the first cry comes the moment it is alarmed, then every `every` seconds while the grudge lasts
	- **Ground clips** (`CryStart`, `CryLoop`, `CryEnd`) stay wired for a bird without `air`
	- **The call:** at `call` seconds (`Scream`, frame 18 of the start) every mob within `radius`, of any kind, turns on its target
	- **Players** aren't stunned by it and play no reaction; their `Player Jay` clips are the answer to its bow now (`greet.answer`)
	- **The shake:** from the call until the loop ends, cameras near it shake and widen, as for the wolf's screech
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local cry: MobTypes.Cry = {
	start = "CryStart",
	loop = "CryLoop",
	finish = "CryEnd",
	air = "FlyCry",
	air_finish = "FlyCryEnd",
	call = 18 / 60,
	hold = { 2, 3 }, --@ Seconds the ground loop holds
	every = { 10, 16 }, --@ Seconds between cries while it keeps its target
	radius = 150, --@ Studs it is heard from
	kinds = nil, --@ Every kind of mob answers
	shake = "CryShake", --@ MockingJayVisuals: the wolf screech's shake and FOV widening, for every player in range while it cries
}

return cry
