local Section = {}

function Section.Brief(mob): string?
	local fight = mob.FightGroup
	if not fight then return nil end

	if fight:IsAttacker(mob) then
		return `slot {fight.Bites[mob] or 0}/{fight:Turn(mob)}`
	end

	if os.clock() < (fight.RestUntil[mob] or 0) then return "resting" end
	if fight.Orbiting[mob] then return "orbiting" end

	return nil
end

function Section.Report(mob): { string }
	local lines = {}

	for _, group in { mob.Team, mob.FightGroup } do
		for _, line in group:Describe(mob) do
			table.insert(lines, line)
		end
	end

	return if #lines > 0 then lines else { "solo" }
end

return Section
