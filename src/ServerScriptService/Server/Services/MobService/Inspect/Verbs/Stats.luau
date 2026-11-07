local Path = require("../../Path")
local Sight = require("../../Senses/Sight")

local sample = { At = os.clock(), Casts = Sight.Casts() }

local function attribute(folder: Instance, name: string): string
	local value = folder:GetAttribute(name)
	return if typeof(value) == "number" then string.format("%.2f", value) else "-"
end

local Verb = { Selects = false }

function Verb.Run(_, context): string
	local states, count = {}, 0

	for mob in context.Mobs do
		count += 1
		local name = if mob.Dead then "dead" else mob.Machine.Name or "idle"
		states[name] = (states[name] or 0) + 1
	end

	local parts = {}

	for name, amount in states do
		table.insert(parts, `{name} {amount}`)
	end

	table.sort(parts)

	local waiting, computing = Path.Backlog()
	local folder = context.Folder
	local now, casts = os.clock(), Sight.Casts()
	local rays = (casts - sample.Casts) / math.max(now - sample.At, 1e-3)

	sample.At, sample.Casts = now, casts

	return table.concat({
		`{count} mobs{if #parts > 0 then ": " .. table.concat(parts, ", ") else ""}`,
		`step ms avg {attribute(folder, "StepMsAvg")}, peak {attribute(folder, "StepMsPeak")}, thinks/s {attribute(folder, "ThinksPerSecond")}`,
		`paths waiting {waiting}, computing {computing}`,
		string.format("sight rays/s %.1f since the last stats", rays),
	}, "\n")
end

return Verb
