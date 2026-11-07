local Geometry = require("./Geometry")

local Orbit = {}

function Orbit.State()
	return { Orbiting = {} }
end

function Orbit.Forget(team, mob)
	team.Orbiting[mob] = nil
end

function Orbit.Describe(team, mob): { string }
	return if team.Orbiting[mob] then { "orbiting" } else {}
end

Orbit.Methods = {}

function Orbit.Methods:SetOrbiting(mob, orbiting: boolean)
	self.Orbiting[mob] = if orbiting then true else nil
end

function Orbit.Methods:OrbitAngle(mob, center: Vector3, lead: number): number
	local ring = {}

	for member in self.Orbiting do
		if member.Root and member.Target == mob.Target then
			table.insert(ring, { Mob = member, Angle = Geometry.AngleAround(center, member.Root.Position) })
		end
	end

	if not self.Orbiting[mob] then
		table.insert(ring, { Mob = mob, Angle = Geometry.AngleAround(center, mob.Root.Position) })
	end

	table.sort(ring, function(a, b)
		return a.Angle < b.Angle
	end)

	local step = math.pi * 2 / #ring
	local x, z, index = 0, 0, 1

	for position, entry in ring do
		local offset = entry.Angle - (position - 1) * step
		x += math.cos(offset)
		z += math.sin(offset)

		if entry.Mob == mob then
			index = position
		end
	end

	return math.atan2(z, x) + (index - 1) * step + lead
end

return Orbit
