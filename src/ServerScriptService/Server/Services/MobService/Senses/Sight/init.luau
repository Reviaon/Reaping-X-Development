local Perception = require("./Perception")
local Eyes = require("@self/Eyes")
local Memory = require("@self/Memory")

local Sight = {}

Sight.Casts = Eyes.Casts

local function distanceTo(mob, target: Model): number
	local root = Perception.RootOf(target)
	return if root then (root.Position - mob.Root.Position).Magnitude else math.huge
end

function Sight.Hears(mob, target: Model): boolean
	local settings = mob.Config.sight
	return not settings or distanceTo(mob, target) <= settings.hear_range
end

function Sight.Sees(mob, target: Model): boolean
	local settings = mob.Config.sight
	if not settings then return true end
	if not mob.Root or not Perception.RootOf(target) then return false end

	local entry = Memory.Entry(mob, target)
	local now = os.clock()

	if now - entry.CheckedAt < settings.interval then return entry.Visible end

	entry.CheckedAt = now
	entry.Visible = Eyes.Clear(mob, target, settings)

	if entry.Visible then
		entry.SeenAt = now
		entry.SeenPosition = Perception.RootOf(target).Position

		if mob.Team then
			mob.Team:NoteSighting(target, now, entry.SeenPosition)
		end
	end

	return entry.Visible
end

function Sight.Notices(mob, target: Model): boolean
	return Sight.Hears(mob, target) or Sight.Sees(mob, target)
end

function Sight.LastSeen(mob, target: Model): (number, Vector3?)
	local entry = Memory.Peek(mob, target)
	local at, position = -math.huge, nil

	if entry then
		at, position = entry.SeenAt, entry.SeenPosition
	end

	local shared = mob.Team and mob.Team:LastSighting(target)

	if shared and shared.At > at then
		at, position = shared.At, shared.Position
	end

	return at, position
end

function Sight.Knows(mob, target: Model): boolean
	local settings = mob.Config.sight
	if not settings then return true end
	if Sight.Notices(mob, target) then return true end

	return os.clock() - (Sight.LastSeen(mob, target)) <= settings.memory
end

function Sight.Noticed(mob, range: number): { Model }
	local noticed = {}

	for _, player in Perception.PlayersNear(mob.Root.Position, range) do
		if Sight.Notices(mob, player) then
			table.insert(noticed, player)
		end
	end

	table.sort(noticed, function(a, b)
		return distanceTo(mob, a) < distanceTo(mob, b)
	end)

	return noticed
end

function Sight.Describe(mob): { string }
	local settings = mob.Config.sight
	if not settings then return { "omniscient (sight = false)" } end

	local now = os.clock()
	local lines = {}

	for target, entry in Memory.Of(mob) do
		if not Perception.IsValidTarget(target) then continue end

		local senses = {}

		if entry.Visible and now - entry.CheckedAt < settings.interval * 2 then
			table.insert(senses, "seen")
		elseif entry.SeenAt > -math.huge then
			table.insert(senses, string.format("last seen %.1fs ago", now - entry.SeenAt))
		else
			table.insert(senses, "never seen")
		end

		local shared = mob.Team and mob.Team:LastSighting(target)

		if shared and shared.At > entry.SeenAt then
			table.insert(senses, string.format("pack saw %.1fs ago", now - shared.At))
		end

		if Sight.Hears(mob, target) then
			table.insert(senses, "heard")
		end

		local known = if Sight.Knows(mob, target) then "known" else "lost"

		table.insert(lines, string.format("%s %.0f studs: %s, %s", target.Name, distanceTo(mob, target), table.concat(senses, ", "), known))
	end

	if #lines == 0 then
		table.insert(lines, "nobody looked at yet")
	end

	return lines
end

return Sight
