--[[@
	**Moves**: the ways a flying mob repositions round its target, picked by weight from `flight.moves`
	- **Each move** returns where to go (an angle round the target and a distance from it), how fast, and whether it keeps facing the target
	- **Faced moves** play the flight set by direction (`Fly Left`/`Right`/`Backwards`/`Forward`); unfaced ones turn into the flight and play `Fly Forward`/`Fly Fast`
	- **`pursue`** is never picked by weight: `Flit` forces it once the target is past `flight.pursue_beyond`, and it flies them down unfaced (`Fly Fast`)
	- **Adding a move:** a new entry here, then a weight in the mob's `flight.moves`
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Config = require("./Config")

export type Plan = {
	Angle: number,
	Distance: number,
	Speed: string | number,
	Faced: boolean,
	Hold: number?,
}

local random = Random.new()

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2] or range[1])
end

local function turn(low: number, high: number): number
	return math.rad(random:NextNumber(low, high))
end

local Moves: { [string]: (flight: MobTypes.Flight, angle: number, side: number, distance: number) -> Plan } = {}

function Moves.drift(flight, angle, side)
	return {
		Angle = angle + side * turn(25, 70),
		Distance = roll(flight.band),
		Speed = flight.speed,
		Faced = true,
	}
end

function Moves.retreat(flight, angle)
	return {
		Angle = angle + turn(-15, 15),
		Distance = flight.band[2] + random:NextNumber(4, 8),
		Speed = flight.speed,
		Faced = true,
	}
end

function Moves.dart(flight, angle)
	return {
		Angle = angle + turn(-15, 15),
		Distance = flight.band[1] * 0.6,
		Speed = flight.dart_speed or flight.speed,
		Faced = true,
	}
end

function Moves.sweep(flight, angle, side)
	return {
		Angle = angle + side * turn(120, 180),
		Distance = roll(flight.band),
		Speed = flight.dart_speed or flight.speed,
		Faced = false,
	}
end

function Moves.pursue(flight, angle)
	return {
		Angle = angle,
		Distance = flight.band[2] * Config.PursueReach,
		Speed = flight.pursue_speed or flight.dart_speed or flight.speed,
		Faced = false,
	}
end

function Moves.hover(flight, angle, _, distance)
	return {
		Angle = angle,
		Distance = distance,
		Speed = 0,
		Faced = true,
		Hold = roll(flight.hold or Config.DefaultHold),
	}
end

return Moves
