--[[@
	**Footsteps**: a big animal's steps are felt as well as seen
	- **Who feels it:** players within `range`; the shake fades with distance and is gone at the edge
	- **Gaits:** one entry per locomotion key in `animations`; each names the shares of its clip where paws strike and the shape it shakes
	- **Run:** the gallop lands its paws in pairs, one beat per pair; **Walk:** the diagonal pairs strike together, a lighter shape
	- **Where it runs:** each client times it from the wolf's own tracks (`StepShakeHandler`), so nothing is sent over the network
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local footsteps: MobTypes.Footsteps = {
	gaits = {
		Run = {
			at = { 0.06, 0.31 }, --@ Front pair, hind pair (measured from M1s_Run's paw heights)
			shake = "WolfStep", --@ ShakeLibrary shape
		},

		Walk = {
			at = { 0.44, 0.94 }, --@ Each diagonal pair (measured from M1s_Walk's paw heights)
			shake = "WolfWalkStep",
		},
	},

	range = 60, --@ Studs from the wolf a player still feels a step
	min_weight = 0.5, --@ A gait's track counts only above this blend weight, so a walk easing into a run gives one gait's steps
}

return footsteps
