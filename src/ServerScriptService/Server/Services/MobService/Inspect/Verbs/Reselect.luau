local Threat = require("../../Combat/Threat")

local Verb = { Selects = true }

function Verb.Run(mobs): string
	local lines = {}

	for _, mob in mobs do
		local before = mob.Target

		Threat.Release(mob)

		if mob.Team then
			mob.Team:Rebalance(mob)
		end

		mob:SetTarget(nil)

		local held = mob.Machine:IsLocked()

		if not held then
			mob.Machine:Exit()
		end

		local focus = mob:Provoker()

		table.insert(lines, string.format("%s: %s → %s%s", mob.Name, if before then before.Name else "none", if focus then focus.Name else "next tick", if held then " (state locked, re-decides after it)" else ""))
	end

	return table.concat(lines, "\n")
end

return Verb
