local State = {}

function State.Brief(mob): string?
	if mob.Dead then return "dead" end

	local name = mob.Machine.Name or "idle"

	return if mob.Blackboard.Retreating then `{name} (retreat)` else name
end

function State.Report(mob, now: number): { string }
	local machine = mob.Machine
	local tier = mob.Tier
	local lines = {}

	if machine.Name then
		local flags = {}

		for flag, on in { locked = machine:IsLocked(), done = machine:IsDone(), armored = mob:IsArmored() } do
			if on then
				table.insert(flags, flag)
			end
		end

		local suffix = if #flags > 0 then ` ({table.concat(flags, ", ")})` else ""

		table.insert(lines, string.format("%s for %.1fs%s", machine.Name, now - machine.EnteredAt, suffix))
	else
		table.insert(lines, if mob.Dead then "dead" else "no state")
	end

	table.insert(lines, string.format("tree %s, thinks every %.2fs%s", mob.Config.tree, tier and tier.interval or 0, if mob:IsDisabled() then ", disabled" else ""))
	table.insert(lines, string.format("hp %d/%d, %.0f studs from home", mob.Humanoid.Health, mob.Humanoid.MaxHealth, mob:HomeDistance()))

	local search = mob.Blackboard.Search

	if search then
		table.insert(lines, string.format("searching for %s, %.1fs left", search.Target.Name, search.Until - now))
	end

	return lines
end

return State
