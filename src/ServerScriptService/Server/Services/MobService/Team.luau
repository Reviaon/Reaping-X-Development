local Perception = require("./Perception")

local Team = {}
Team.__index = Team

Team.Settings = {
	BalanceInterval = 1,
	Stickiness = 12,
}

local teams = {}
local random = Random.new()

local function planarDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function angleAround(center: Vector3, position: Vector3): number
	local offset = position - center
	return math.atan2(offset.Z, offset.X)
end

function Team.Join(mob, key: any)
	if key == nil then return nil end

	local team = teams[key]

	if not team then
		team = setmetatable({
			Key = key,
			Members = {},
			Targets = {},
			Assignment = {},
			BalancedTargets = {},
			NextBalanceAt = 0,
			Slots = {},
			Bites = {},
			RestUntil = {},
			Orbiting = {},
			Reservations = {},
			Turns = {},
			BreakIns = {},
			Engaged = {},
			Assaults = setmetatable({}, { __mode = "k" }),
		}, Team)

		teams[key] = team
	end

	team.Members[mob] = true
	mob.Team = team

	return team
end

function Team.Get(key: any)
	return teams[key]
end

function Team:Leave(mob)
	self.Members[mob] = nil
	self.Slots[mob] = nil
	self.Bites[mob] = nil
	self.RestUntil[mob] = nil
	self.Orbiting[mob] = nil
	self.Assignment[mob] = nil
	self.Turns[mob] = nil
	self.BreakIns[mob] = nil
	self.Engaged[mob] = nil

	if next(self.Members) == nil then
		teams[self.Key] = nil
	end
end

function Team:Holds(target: Model, range: number, except): boolean
	local root = Perception.RootOf(target)
	if not root then return false end

	for member in self.Members do
		if member == except or member.Dead or not member.Root then continue end

		if (member.Root.Position - root.Position).Magnitude <= range then
			return true
		end
	end

	return false
end

function Team:Share(target: Model)
	if Perception.IsValidTarget(target) then
		self.Targets[target] = true
	end
end

function Team:Drop(target: Model)
	self.Targets[target] = nil
end

function Team:Prune(range: number)
	for target in self.Targets do
		if not Perception.IsValidTarget(target) or not self:Holds(target, range) then
			self.Targets[target] = nil
		end
	end
end

local function provokerOf(member): Model?
	return if member.Provoker then member:Provoker() else nil
end

function Team:TargetsChanged(): boolean
	for target in self.Targets do
		if not self.BalancedTargets[target] then return true end
	end

	for target in self.BalancedTargets do
		if not self.Targets[target] then return true end
	end

	return false
end

function Team:Balance()
	local settings = Team.Settings
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
				cost -= settings.Stickiness
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
	self.NextBalanceAt = os.clock() + settings.BalanceInterval
end

function Team:Engage(mob, engaged: boolean)
	if (self.Engaged[mob] == true) == engaged then return end

	self.Engaged[mob] = if engaged then true else nil
	self.NextBalanceAt = 0

	if not engaged then
		self.Assignment[mob] = nil
	end
end

function Team:Assign(mob, range: number): Model?
	self:Prune(range)

	if os.clock() >= self.NextBalanceAt or self:TargetsChanged() or (next(self.Targets) and not self.Assignment[mob]) then
		self:Balance()
	end

	return self.Assignment[mob]
end

local function resting(self, mob, now: number): boolean
	return now < (self.RestUntil[mob] or 0)
end

function Team:Attackers(target: Model): number
	local attackers = 0

	for member in self.Slots do
		if member.Target == target then
			attackers += 1
		end
	end

	return attackers
end

function Team:NextInLine(target: Model, center: Vector3, now: number)
	local best, bestDistance = nil, math.huge

	for member in self.Members do
		if self.Slots[member] or resting(self, member, now) then continue end
		if member.Dead or member.Target ~= target or not member.Root then continue end

		local distance = (member.Root.Position - center).Magnitude

		if distance < bestDistance then
			best, bestDistance = member, distance
		end
	end

	return best
end

function Team:Crowded(mob, target: Model, center: Vector3, clearance: number): boolean
	for member in self.Members do
		if member == mob or member.Dead or not member.Root or member.Target ~= target then continue end

		if planarDistance(member.Root.Position, center) < clearance then
			return true
		end
	end

	return false
end

function Team:ClaimSlot(mob, center: Vector3): boolean
	local pack = mob.Config.pack
	if not pack then return true end

	local now = os.clock()
	local target = mob.Target
	local expiresAt = self.Slots[mob]

	if expiresAt then
		local turn = self.Turns[mob] or pack.bites_per_turn or math.max(#(mob.Config.attack.animations or {}), 1)
		local spent = (self.Bites[mob] or 0) >= turn

		if now < expiresAt and not spent then return true end

		self.Slots[mob] = nil
		self.Bites[mob] = nil
		self.Turns[mob] = nil
		self.RestUntil[mob] = now + pack.rest_time

		return false
	end

	local breakIn = self.BreakIns[mob]

	if breakIn then
		self.BreakIns[mob] = nil

		if breakIn.Target == target and now < breakIn.Until then
			self.Slots[mob] = now + pack.engage_time
			self.Bites[mob] = 0
			self.Turns[mob] = breakIn.Bites
			self.RestUntil[mob] = nil
			mob.Blackboard.LastAttackAt = nil

			return true
		end
	end

	if resting(self, mob, now) then return false end
	if self:Attackers(target) >= pack.max_attackers then return false end
	if pack.clearance and self:Crowded(mob, target, center, pack.clearance) then return false end

	local candidate = self:NextInLine(target, center, now)
	if candidate and candidate ~= mob then return false end

	self.Slots[mob] = now + pack.engage_time
	self.Bites[mob] = 0
	mob.Blackboard.LastAttackAt = nil

	return true
end

function Team:Reserve(target: Model, key: string, seconds: number): boolean
	local reservations = self.Reservations[target]
	local now = os.clock()

	if reservations and (reservations[key] or 0) > now then return false end

	reservations = reservations or {}
	reservations[key] = now + seconds
	self.Reservations[target] = reservations

	return true
end

function Team:Reserved(target: Model, key: string): boolean
	local reservations = self.Reservations[target]
	return reservations ~= nil and (reservations[key] or 0) > os.clock()
end

function Team:IsAttacker(mob): boolean
	return self.Slots[mob] ~= nil
end

function Team:NoteAttack(mob)
	if self.Slots[mob] then
		self.Bites[mob] = (self.Bites[mob] or 0) + 1
	end
end

function Team:ReleaseSlot(mob)
	self.Slots[mob] = nil
	self.Bites[mob] = nil
	self.Turns[mob] = nil
end

function Team:BreakInCandidate(victim, attacker: Model)
	local root = Perception.RootOf(attacker)
	if not root then return nil end

	local best, bestDistance = nil, math.huge

	for member in self.Members do
		if member == victim or member.Dead or not member.Root or member.Target ~= attacker then continue end
		if self.Slots[member] or member:IsDisabled() then continue end

		local distance = planarDistance(member.Root.Position, root.Position)

		if distance < bestDistance then
			best, bestDistance = member, distance
		end
	end

	return best
end

local function roll(value, whole: boolean?): number
	if typeof(value) ~= "table" then return value end

	return if whole then random:NextInteger(value[1], value[2]) else random:NextNumber(value[1], value[2])
end

function Team:NoteAssault(victim, attacker: Model)
	local pack = victim.Config.pack
	local breakIn = pack and pack.break_in
	if not breakIn then return end

	local now = os.clock()
	local assault = self.Assaults[attacker]

	if not assault or now - assault.LastAt > breakIn.window then
		assault = { Count = 0, LastAt = now, Need = roll(breakIn.after, true), ReadyAt = assault and assault.ReadyAt or 0 }
		self.Assaults[attacker] = assault
	end

	assault.Count += 1
	assault.LastAt = now

	if assault.Count < assault.Need or now < assault.ReadyAt then return end

	assault.Count = 0
	assault.Need = roll(breakIn.after, true)

	if random:NextNumber() > breakIn.chance then return end

	local member = self:BreakInCandidate(victim, attacker)
	if not member then return end

	assault.ReadyAt = now + roll(breakIn.cooldown)
	self.BreakIns[member] = { Target = attacker, Until = now + breakIn.window, Bites = roll(breakIn.bites, true) }
end

function Team:SetOrbiting(mob, orbiting: boolean)
	self.Orbiting[mob] = if orbiting then true else nil
end

function Team:OrbitAngle(mob, center: Vector3, lead: number): number
	local ring = {}

	for member in self.Orbiting do
		if member.Root and member.Target == mob.Target then
			table.insert(ring, { Mob = member, Angle = angleAround(center, member.Root.Position) })
		end
	end

	if not self.Orbiting[mob] then
		table.insert(ring, { Mob = mob, Angle = angleAround(center, mob.Root.Position) })
	end

	table.sort(ring, function(a, b)
		return a.Angle < b.Angle
	end)

	local step = math.pi * 2 / #ring
	local x, z, index = 0, 0, 1

	for position, entry in ring do
		local offset = entry.Angle - (position - 1) * step
		x += math.cos(offset)
		z += math.sin(offset)

		if entry.Mob == mob then
			index = position
		end
	end

	return math.atan2(z, x) + (index - 1) * step + lead
end

return Team
