--[[@
	**Cry**: the alarm
	- **Always on the ground:** `CryStart`, the looped `CryLoop`, then `CryEnd`; on spotting a player, then every `every` seconds while it still watches them
	- **From the air** it lands first (`Land`), then cries, then takes off again
	- **The call:** at `call` seconds (`Scream`, frame 18 of the start) every mob within `radius`, of any kind, turns on its target
	- **The stun:** players within `stun.range` are stunned for `stun.duration` and cover up (`Player Jay Startup`, then the looped `Player Jay Loop`), turning to face it
	- **The shake:** from the call until the loop ends, cameras near it shake and widen, as for the wolf's screech
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local cry: MobTypes.Cry = {
	start = "CryStart",
	loop = "CryLoop",
	finish = "CryEnd",
	air = nil, --@ No air cry: from the air it lands first (`LandToCry`), then cries on the ground; `"FlyCry"` would cry on the wing
	call = 18 / 60,
	hold = { 2, 3 }, --@ Seconds the ground loop holds
	every = { 10, 16 }, --@ Seconds between cries while it keeps its target
	radius = 150, --@ Studs it is heard from
	kinds = nil, --@ Every kind of mob answers
	shake = "CryShake", --@ MockingJayVisuals: the wolf screech's shake and FOV widening, for every player in range while it cries
	stun = {
		range = 28,
		duration = 2.5,
		start = "Player Jay Startup",
		loop = "Player Jay Loop",
	},
}

return cry
