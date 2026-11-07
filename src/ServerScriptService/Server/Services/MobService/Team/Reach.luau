local Reach = {}

function Reach.State()
	return { Reach = setmetatable({}, { __mode = "k" }) }
end

function Reach.Describe(team): { string }
	local lines = {}
	local now = os.clock()

	for target, evidence in team.Reach do
		if now < evidence.Until then
			table.insert(lines, string.format("shared: %s unreachable for %.1fs", target.Name, evidence.Until - now))
		end
	end

	return lines
end

Reach.Methods = {}

function Reach.Methods:NoteReach(target: Model, evidence)
	self.Reach[target] = evidence
end

function Reach.Methods:ReachOf(target: Model, now: number)
	local evidence = self.Reach[target]
	if not evidence then return nil end

	if now >= evidence.Until then
		self.Reach[target] = nil
		return nil
	end

	return evidence
end

return Reach
