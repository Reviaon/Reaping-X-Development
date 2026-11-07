local Threat = require("../../Combat/Threat")

local Section = {} 

function Section.Brief(mob): string?
	local target = mob.Target
	if not target then return nil end

	local score = Threat.Score(mob, target)

	return if score > 0 then string.format("→ %s %.0f", target.Name, score) else `→ {target.Name}`
end

function Section.Report(mob, now: number): { string }
	local lines = {}
	local target = mob.Target
	local ledger = mob.Ledger

	table.insert(lines, `target {if target then target.Name else "none"}`)

	local rows = Threat.Dump(mob)

	if #rows == 0 then
		table.insert(lines, "ledger empty")
		return lines
	end

	for _, row in rows do
		table.insert(lines, string.format("%s %s %.1f", if row.Focus then "*" else " ", row.Target.Name, row.Score))
	end

	if ledger.Focus then
		table.insert(lines, string.format("focus held %.1fs", now - ledger.FocusSince))
	end

	return lines
end

return Section
