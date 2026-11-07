local Section = {}

function Section.Brief(mob): string?
	local team = mob.Team
	if not team then return nil end

	if team:IsAttacker(mob) then
		return `slot {team.Bites[mob] or 0}/{team:Turn(mob)}`
	end

	if os.clock() < (team.RestUntil[mob] or 0) then return "resting" end
	if team.Orbiting[mob] then return "orbiting" end

	return nil
end

function Section.Report(mob): { string }
	local team = mob.Team

	return if team then team:Describe(mob) else { "solo" }
end

return Section
