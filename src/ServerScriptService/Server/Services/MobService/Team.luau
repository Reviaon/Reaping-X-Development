local Perception = require("./Perception")

local Team = {}
Team.__index = Team

local teams = {}

local function count(set): number
	local total = 0

	for _ in set do
		total += 1
	end

	return total
end

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
			Target = nil,
			Slots = {},
			Bites = {},
			RestUntil = {},
			Orbiting = {},
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

	if next(self.Members) == nil then
		teams[self.Key] = nil
	end
end

function Team:GetTarget(): Model?
	if self.Target and not Perception.IsValidTarget(self.Target) then
		self.Target = nil
	end

	return self.Target
end

function Team:Share(target: Model)
	if self:GetTarget() then return end

	self.Target = target
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

function Team:Drop(target: Model)
	if self.Target == target then
		self.Target = nil
	end
end

local function resting(self, mob, now: number): boolean
	return now < (self.RestUntil[mob] or 0)
end

function Team:NextInLine(center: Vector3, now: number)
	local best, bestDistance = nil, math.huge

	for member in self.Members do
		if self.Slots[member] or resting(self, member, now) then continue end
		if member.Dead or member.Target ~= self.Target or not member.Root then continue end

		local distance = (member.Root.Position - center).Magnitude

		if distance < bestDistance then
			best, bestDistance = member, distance
		end
	end

	return best
end

function Team:Crowded(mob, center: Vector3, clearance: number): boolean
	for member in self.Members do
		if member == mob or member.Dead or not member.Root then continue end

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
	local expiresAt = self.Slots[mob]

	if expiresAt then
		local spent = (self.Bites[mob] or 0) >= (pack.bites_per_turn or math.huge)

		if now < expiresAt and not spent then return true end

		self.Slots[mob] = nil
		self.Bites[mob] = nil
		self.RestUntil[mob] = now + pack.rest_time

		return false
	end

	if resting(self, mob, now) then return false end
	if count(self.Slots) >= pack.max_attackers then return false end
	if pack.clearance and self:Crowded(mob, center, pack.clearance) then return false end

	local candidate = self:NextInLine(center, now)
	if candidate and candidate ~= mob then return false end

	self.Slots[mob] = now + pack.engage_time
	self.Bites[mob] = 0

	return true
end

function Team:NoteAttack(mob)
	if self.Slots[mob] then
		self.Bites[mob] = (self.Bites[mob] or 0) + 1
	end
end

function Team:ReleaseSlot(mob)
	self.Slots[mob] = nil
	self.Bites[mob] = nil
end

function Team:SetOrbiting(mob, orbiting: boolean)
	self.Orbiting[mob] = if orbiting then true else nil
end

function Team:OrbitAngle(mob, center: Vector3, lead: number): number
	local ring = {}

	for member in self.Orbiting do
		if member.Root then
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
