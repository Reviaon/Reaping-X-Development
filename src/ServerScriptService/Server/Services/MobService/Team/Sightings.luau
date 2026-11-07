local Sightings = {}

function Sightings.State()
	return { Sightings = setmetatable({}, { __mode = "k" }) }
end

function Sightings.Describe(team): { string }
	local lines = {}
	local now = os.clock()

	for target, sighting in team.Sightings do
		table.insert(lines, string.format("pack last saw %s %.1fs ago", target.Name, now - sighting.At))
	end

	return lines
end

Sightings.Methods = {}

function Sightings.Methods:NoteSighting(target: Model, now: number, position: Vector3)
	self.Sightings[target] = { At = now, Position = position }
end

function Sightings.Methods:LastSighting(target: Model)
	return self.Sightings[target]
end

return Sightings
