--[[@
	**Flit**: a flying mob's harrying flight round its target, in place of a fixed orbit
	- **Moves:** one at a time, picked by weight from `flight.moves` (never the same twice running): drift sideways, back off, dart in, hover, sweep to the far side (`./Moves`)
	- **Pursuit:** once the target is past `flight.pursue_beyond` studs (ground plane) it drops whatever it was doing and flies them down unfaced at `pursue_speed` (`Fly Fast`) until it is back in its band
	- **Facing:** faced moves keep it looking at the target, so the flight set plays by direction; a sweep turns into the flight
	- **Steering:** it curves onto each new heading at `flight.agility` rad/s, chasing a point `Carrot` studs ahead, rather than snapping straight
	- **Height:** each move picks its own altitude, `flight.altitude` plus `flight.bob`
	- **A move ends** on reaching its point (`Arrive` studs, ground plane), after its hover, or after `Timeout` seconds
	- **Args:** `focus` names a Blackboard key holding the model to fly round (default: its target); `profile` names a config section whose `flight` table overrides parts of `flight` (`States/Alarm/Escort` passes `Companion` and `greet` for the MockingJay's passive visit)
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../../../Senses/Perception")

local Config = require("@self/Config")
local Moves = require("@self/Moves")

local FLAT = Vector3.new(1, 0, 1)

local random = Random.new()

local function settingsOf(mob, profile: string?): MobTypes.Flight
	local base = mob.Config.flight
	local section = profile and mob.Config[profile]
	local overrides = section and section.flight

	if not overrides then return base end

	return setmetatable(table.clone(overrides), { __index = base }) :: any
end

local function focusOf(mob, data): BasePart?
	if data.Focus then
		return Perception.RootOf(mob.Blackboard[data.Focus])
	end

	return mob:TargetRoot()
end

local function flat(vector: Vector3): Vector3
	return vector * FLAT
end

local function pick(flight: MobTypes.Flight, last: string?): string
	local total = 0

	for name, weight in flight.moves do
		if name ~= last and Moves[name] then
			total += weight
		end
	end

	local roll = random:NextNumber(0, total)

	for name, weight in flight.moves do
		if name == last or not Moves[name] then continue end

		roll -= weight
		if roll <= 0 then return name end
	end

	return "drift"
end

local function farOff(flight: MobTypes.Flight, distance: number): boolean
	return distance > (flight.pursue_beyond or flight.band[2] + Config.PursueMargin)
end

local function plan(mob, data, flight: MobTypes.Flight, centre: Vector3)
	local offset = flat(mob.Root.Position - centre)
	local angle = if offset.Magnitude > 1e-3 then math.atan2(offset.Z, offset.X) else random:NextNumber(0, math.pi * 2)

	if random:NextNumber() < Config.FlipChance then
		data.Side = -data.Side
	end

	local name = if farOff(flight, offset.Magnitude) then Config.Pursue else pick(flight, data.Last)
	local move = Moves[name](flight, angle, data.Side, offset.Magnitude)
	local bob = flight.bob

	data.Last = name
	data.Move = move
	data.Started = os.clock()
	mob.Altitude = flight.altitude + (if bob then random:NextNumber(bob[1], bob[2]) else 0)
end

local function goalOf(move: Moves.Plan, centre: Vector3): Vector3
	return centre + Vector3.new(math.cos(move.Angle), 0, math.sin(move.Angle)) * move.Distance
end

local function steer(heading: Vector3, desired: Vector3, limit: number): Vector3
	local between = math.atan2(heading:Cross(desired).Y, heading:Dot(desired))
	local step = math.clamp(between, -limit, limit)

	return (CFrame.Angles(0, step, 0) * heading).Unit
end

local function finished(mob, data, centre: Vector3): boolean
	local move = data.Move
	local elapsed = os.clock() - data.Started

	if move.Hold then return elapsed >= move.Hold end
	if elapsed >= Config.Timeout then return true end

	return flat(goalOf(move, centre) - mob.Root.Position).Magnitude <= Config.Arrive
end

return {
	Enter = function(mob, data, args)
		data.Focus = args and args.focus
		data.Flight = settingsOf(mob, args and args.profile)
		data.Side = if random:NextNumber() < 0.5 then -1 else 1
		data.Tick = os.clock()
		mob:Unface()
	end,

	Update = function(mob, data)
		local flight = data.Flight
		local root = focusOf(mob, data)
		local now = os.clock()
		local dt = now - data.Tick

		data.Tick = now

		if not root then
			mob.Altitude = flight.altitude
			mob:Stop()
			return
		end

		local centre = root.Position

		local fleeing = data.Last ~= Config.Pursue and farOff(flight, flat(mob.Root.Position - centre).Magnitude)

		if not data.Move or fleeing or finished(mob, data, centre) then
			plan(mob, data, flight, centre)
		end

		local move = data.Move

		if move.Faced then
			mob:Face(centre)
		else
			mob:Unface()
		end

		if move.Hold then
			mob:Stop()
			return
		end

		local position = mob.Root.Position
		local desired = flat(goalOf(move, centre) - position)
		if desired.Magnitude <= 1e-3 then return end

		desired = desired.Unit

		local velocity = flat(mob.Root.AssemblyLinearVelocity)
		local heading = data.Heading or (if velocity.Magnitude > 1 then velocity.Unit else desired)

		heading = steer(heading, desired, (flight.agility or Config.DefaultAgility) * dt)
		data.Heading = heading

		mob:MoveTo(position + heading * Config.Carrot, move.Speed)
	end,

	Exit = function(mob)
		mob:Unface()
		mob:Stop()
	end,
}
