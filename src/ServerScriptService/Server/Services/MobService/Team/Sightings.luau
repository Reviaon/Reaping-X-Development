local Sightings = {}

function Sightings.State()
	return { Sightings = setmetatable({}, { __mode = "k" }) }
end

function Sightings.Describe(team): { string }
	local lines = {}
	local now = os.clock()

	for target, at in team.Sightings do
		table.insert(lines, string.format("pack last saw %s %.1fs ago", target.Name, now - at))
	end

	return lines
end

Sightings.Methods = {}

function Sightings.Methods:NoteSighting(target: Model, now: number)
	self.Sightings[target] = now
end

function Sightings.Methods:LastSighting(target: Model): number?
	return self.Sightings[target]
end

return Sightings
