--[[@
	**Lurk**: once it lets go of a seizing player, the snake keeps its distance and darts in to nip them
	- **While:** its target is still held in the crush scene it backed out of (`Conditions/Lurking`)
	- **Distance:** it holds `band` studs from the player's body, facing them
	- **Nips:** every `nip.every` seconds it slides in to `nip.reach`, stops and bites with the stance bite, and backs out again
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local lurk: MobTypes.Lurk = {
	band = { 10, 13 }, --@ Studs from the player's torso
	nip = {
		first = { 0.4, 0.8 }, --@ Seconds after it settles back before the first nip
		every = { 0.8, 1.4 }, --@ Seconds between nips; after the 1.8s retreat the 4.7s seizure fits one, sometimes two
		damage = 3,
		animation = "Strike",
		visual = "Strike", --@ SnakeVisuals: the strike streak
		windup = 0.25, --@ The jaw at full stretch, 9.3 ahead of the root (`snake attack` keyframe 0.167 is 7.4)
		recovery = 0.6,
		reach = 9, --@ Studs root to body it slides in to before biting
		speed = 24,
		approach = 0.8, --@ Seconds it slides in before biting anyway
	},
}

return lurk
