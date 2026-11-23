--[[@
	**Escort**: a passive bird's flight round the player it is visiting (`greet`)
	- **Flit's flight** round the `Companion` on the Blackboard instead of a target, with `greet.flight` overriding parts of `flight` (lower, closer, no pursuit)
	- **Its own name** so the tree can switch between it and an alarmed `Flit` cleanly
]]
local Flit = require("./Flit")

local ARGS = { focus = "Companion", profile = "greet" }

return {
	Enter = function(mob, data)
		Flit.Enter(mob, data, ARGS)
	end,

	Update = Flit.Update,
	Exit = Flit.Exit,
}
