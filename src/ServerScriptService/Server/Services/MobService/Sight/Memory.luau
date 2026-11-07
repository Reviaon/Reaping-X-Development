local Memory = {}

function Memory.Of(mob)
	local memory = mob.Sightings

	if not memory then
		memory = setmetatable({}, { __mode = "k" })
		mob.Sightings = memory
	end

	return memory
end

function Memory.Entry(mob, target: Model)
	local memory = Memory.Of(mob)
	local entry = memory[target]

	if not entry then
		entry = { CheckedAt = -math.huge, Visible = false, SeenAt = -math.huge }
		memory[target] = entry
	end

	return entry
end

function Memory.Peek(mob, target: Model)
	local memory = mob.Sightings
	return memory and memory[target]
end

return Memory
