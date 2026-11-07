local Perception = require("../Perception")
local Config = require("./Config")

local Balance = {}

function Balance.State()
	return {
		Assignment = {},
		BalancedTargets = {},
		NextBalanceAt = 0,
		Engaged = {},
	}
end

function Balance.Forget(team, mob)
	team.Assignment[mob] = nil
	team.Engaged[mob] = nil
end

function Balance.Describe(team, mob): { string }
	local assigned = team.Assignment[mob]
	local engaged = if team.Engaged[mob] then "engaged" else "not engaged"

	return { `{engaged}, assigned {if assigned then assigned.Name else "nothing"}` }
end

local function provokerOf(member): Model?
	return if member.Provoker then member:Provoker() else nil
end

Balance.Methods = {}

function Balance.Methods:TargetsChanged(): boolean
	for target in self.Targets do
		if not self.BalancedTargets[target] then return true end
	end

	for target in self.BalancedTargets do
		if not self.Targets[target] then return true end
	end

	return false
end

function Balance.Methods:Balance()
	local targets, members = {}, {}

	for target in self.Targets do
		table.insert(targets, target)
	end

	for member in self.Members do
		if not member.Dead and member.Root and self.Engaged[member] then
			table.insert(members, member)
		end
	end

	local assignment, loads = {}, {}
	local capacity = if #targets > 0 then math.ceil(#members / #targets) else 0

	for _, member in members do
		local provoker = provokerOf(member)

		if provoker and self.Targets[provoker] then
			assignment[member] = provoker
			loads[provoker] = (loads[provoker] or 0) + 1
		end
	end

	local candidates = {}

	for _, member in members do
		if assignment[member] then continue end

		for _, target in targets do
			local cost = (Perception.RootOf(target).Position - member.Root.Position).Magnitude

			if self.Assignment[member] == target then
				cost -= Config.Stickiness
			end

			table.insert(candidates, { Member = member, Target = target, Cost = cost })
		end
	end

	table.sort(candidates, function(a, b)
		return a.Cost < b.Cost
	end)

	for _, candidate in candidates do
		if assignment[candidate.Member] then continue end
		if (loads[candidate.Target] or 0) >= capacity then continue end

		assignment[candidate.Member] = candidate.Target
		loads[candidate.Target] = (loads[candidate.Target] or 0) + 1
	end

	self.Assignment = assignment
	self.BalancedTargets = table.clone(self.Targets)
	self.NextBalanceAt = os.clock() + Config.BalanceInterval
end

function Balance.Methods:Engage(mob, engaged: boolean)
	if (self.Engaged[mob] == true) == engaged then return end

	self.Engaged[mob] = if engaged then true else nil
	self.NextBalanceAt = 0

	if not engaged then
		self.Assignment[mob] = nil
	end
end

function Balance.Methods:Rebalance(mob)
	self.Assignment[mob] = nil
	self.NextBalanceAt = 0
end

function Balance.Methods:Assign(mob, range: number): Model?
	self:Prune(range)

	if os.clock() >= self.NextBalanceAt or self:TargetsChanged() or (next(self.Targets) and not self.Assignment[mob]) then
		self:Balance()
	end

	return self.Assignment[mob]
end

return Balance
