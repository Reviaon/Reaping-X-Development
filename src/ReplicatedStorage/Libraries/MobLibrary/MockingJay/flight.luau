--[[@
	**Flight**: after the first cry it lifts off high over its target and harries them from the air (`States/Alarm/Flit`)
	- **Height:** about 32 studs up, each move picking its own height within `bob`
	- **Moves:** it drifts sideways, backs off, darts in, hangs in place and now and then sweeps over to the far side; it faces the target on all but the sweep, so `Fly Left`/`Right`/`Backwards`/`Idle` play as it goes
	- **Aerial chase:** a target that gets past `pursue_beyond` is flown down at `pursue_speed` on `Fly Fast`
	- **Climb and descent** are studs/s of lift; it lands with `land` once the lift is down to `land_lift`
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local flight: MobTypes.Flight = {
	altitude = 32, --@ Studs above standing
	bob = { -4, 4 },
	climb = 14,
	descent = 16,
	band = { 14, 26 }, --@ Ground-plane studs from its target it keeps to
	speed = 16, --@ Drifting and backing off
	dart_speed = 26, --@ Darts and sweeps; past 20 forward it plays `Fly Fast`
	agility = 4, --@ Radians/s it curves onto a new heading
	hold = { 0.4, 1 }, --@ Seconds a hover hangs in place
	moves = { --@ Relative weights, `States/Alarm/Flit/Moves`
		drift = 4,
		hover = 2,
		retreat = 1.5,
		dart = 1.5,
		sweep = 1,
	},
	pursue_beyond = 34, --@ Ground-plane studs past which it gives chase
	pursue_speed = 30,
	pace = 12, --@ Studs/s the flight clips play at 1x: drifting at 16 beats 1.33x
	land = "Land",
	land_lift = 6.7, --@ Studs of lift left when `Land` starts: at `descent` it touches down on the clip's `land` frame (0.42s)
	land_settle = 0.6, --@ Seconds into `Land` it moves on (the clip fades under the run), rather than waiting out its 1.8s settle
}

return flight
