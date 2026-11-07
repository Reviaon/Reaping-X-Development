local Perception = require("../MobService/Senses/Perception")

local Population = {}

function Population.Track(zone, mob)
	zone.Mobs[mob] = { OutSince = nil }

	mob.Died:Connect(function()
		zone.LastKillAt = os.clock()
	end)
end

function Population.Sweep(zone, MobService, settings, now: number): boolean
	local occupied = next(zone.Mobs) ~= nil

	for mob, record in zone.Mobs do
		if mob.Destroyed then
			zone.Mobs[mob] = nil
			continue
		end

		if mob.Dead then continue end

		if Perception.NearestPlayerDistance(mob.Root.Position) <= settings.DespawnRange then
			record.OutSince = nil
			continue
		end

		record.OutSince = record.OutSince or now

		if now - record.OutSince >= settings.DespawnGrace then
			MobService:Despawn(mob)
		end
	end

	return occupied and next(zone.Mobs) == nil
end

return Population
