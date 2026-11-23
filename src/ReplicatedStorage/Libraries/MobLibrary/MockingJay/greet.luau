--[[@
	**Greet**: left alone, the MockingJay is a friendly bird that comes to visit players
	- **Circle:** it flies round a player it notices, low and close (`flight` overrides its flight here), for `circle` seconds
	- **Hello:** it lands, walks up to `distance` studs, looks them over (`Startup`) and bows (`Bow`, held `hold` seconds)
	- **Answer:** while it bows a player beside it may interact (`answer`): they turn to the bird and play `Player Jay Startup`, then the looped `Player Jay Loop`, for `answer.duration` seconds, and the bird holds its bow with them
	  - They are stood `answer.spacing` studs in front of it, square to it, so their hand comes down on its bowed head; it holds over shift lock
	  - Nothing holds the player: walking off ends their gesture early
	  - Left unanswered, the bow just ends after `hold`
	- **Tag along:** it follows them for `follow` seconds, on foot or, `fly_chance` of the time, on the wing
	- **Then** it leaves them be for `cooldown` seconds, wandering and pecking at the ground
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local greet: MobTypes.Greet = {
	range = 40, --@ Studs it notices a player to visit from
	circle = { 3, 5 },
	flight = {
		altitude = 10,
		bob = { -2, 2 },
		band = { 8, 14 },
		moves = { drift = 3, hover = 2, sweep = 1 },
		pursue_beyond = math.huge, --@ It never chases a player who walks off; the visit just ends
	},
	distance = 5,
	startup = "Startup",
	bow = "Bow",
	hold = { 3.5, 4.5 }, --@ Long enough to see the interaction and take it
	answer = {
		action = "Bow", --@ The interaction's text
		object = "MockingJay",
		reach = 10, --@ Studs from the bird it can be taken from
		offset = Vector3.new(0, 2, 0), --@ Where it sits, from the bird's root (at its feet)
		start = "Player Jay Startup",
		loop = "Player Jay Loop",
		duration = 3, --@ Seconds the player's gesture lasts, and the bird's bow with it
		spacing = 3.9, --@ Studs between the two roots: the player's hand reaches 1.9 ahead of them, the bowed head sits 2 ahead of the bird
		side = 0, --@ Studs the player stands to their right of that line; the hand comes to their own midline, so none
	},
	follow = { 2, 4 },
	follow_distance = 6,
	follow_altitude = 6,
	fly_chance = 0.4,
	cooldown = { 15, 25 },
	give_up = 30, --@ Seconds a visit may last at most
}

return greet
