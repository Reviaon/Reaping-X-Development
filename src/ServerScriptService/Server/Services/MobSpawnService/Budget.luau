local Zone = require("./Zone")

local Budget = {}

function Budget.Queue(zones, settings)
	local queue = {}

	for _, zone in zones do
		local distance = Zone.NearestPlayer(zone)

		if distance <= settings.ActivationRange then
			table.insert(queue, { Zone = zone, Distance = distance })
		elseif next(zone.Mobs) == nil then
			zone.Status = if distance == math.huge then "no players" else string.format("idle, nearest player %.0f studs", distance)
		end
	end

	table.sort(queue, function(a, b)
		return a.Distance < b.Distance
	end)

	return queue
end

function Budget.Fit(wanted: number, minimum: number, room: number): number?
	if room >= wanted then return wanted end
	if room > 0 and room >= minimum then return room end

	return nil
end

return Budget
