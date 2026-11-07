local Geometry = require("./Geometry")

local Slots = {}

function Slots.State()
	return {
		Slots = {},
		Bites = {},
		Turns = {},
		RestUntil = {},
	}
end

function Slots.Forget(team, mob)
	team.Slots[mob] = nil
	team.Bites[mob] = nil
	team.Turns[mob] = nil
	team.RestUntil[mob] = nil
end

local function resting(team, mob, now: number): boolean
	return now < (team.RestUntil[mob] or 0)
end

function Slots.Describe(team, mob): { string }
	local now = os.clock()
	local pack = mob.Config.pack
	local cap = if pack then pack.max_attackers else "?"
	local attackers = if mob.Target then team:Attackers(mob.Target) else 0
	local expiresAt = team.Slots[mob]

	if expiresAt then
		return { string.format("attacker %d/%s, bites %d/%d, %.1fs left", attackers, tostring(cap), team.Bites[mob] or 0, team:Turn(mob), math.max(expiresAt - now, 0)) }
	end

	if resting(team, mob, now) then
		return { string.format("resting %.1fs, %d/%s attacking", team.RestUntil[mob] - now, attackers, tostring(cap)) }
	end

	return { string.format("waiting, %d/%s attacking", attackers, tostring(cap)) }
end

local function open(team, mob, now: number, seconds: number, bites: number?)
	team.Slots[mob] = now + seconds
	team.Bites[mob] = 0
	team.Turns[mob] = bites
	mob.Blackboard.LastAttackAt = nil
end

Slots.Methods = {}

function Slots.Methods:Attackers(target: Model): number
	local attackers = 0

	for member in self.Slots do
		if member.Target == target then
			attackers += 1
		end
	end

	return attackers
end

function Slots.Methods:NextInLine(target: Model, center: Vector3, now: number)
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

function Slots.Methods:Crowded(mob, target: Model, center: Vector3, clearance: number): boolean
	for member in self.Members do
		if member == mob or member.Dead or not member.Root or member.Target ~= target then continue end

		if Geometry.Planar(member.Root.Position, center) < clearance then
			return true
		end
	end

	return false
end

function Slots.Methods:ClaimSlot(mob, center: Vector3): boolean
	local pack = mob.Config.pack
	if not pack then return true end

	local now = os.clock()
	local target = mob.Target
	local expiresAt = self.Slots[mob]

	if expiresAt then
		local spent = (self.Bites[mob] or 0) >= self:Turn(mob)

		if now < expiresAt and not spent then return true end

		self:ReleaseSlot(mob)
		self.RestUntil[mob] = now + pack.rest_time

		return false
	end

	local breakIn = self:TakeBreakIn(mob)

	if breakIn and breakIn.Target == target and now < breakIn.Until then
		open(self, mob, now, pack.engage_time, breakIn.Bites)
		self.RestUntil[mob] = nil

		return true
	end

	if resting(self, mob, now) then return false end
	if self:Attackers(target) >= pack.max_attackers then return false end
	if pack.clearance and self:Crowded(mob, target, center, pack.clearance) then return false end

	local candidate = self:NextInLine(target, center, now)
	if candidate and candidate ~= mob then return false end

	open(self, mob, now, pack.engage_time, nil)

	return true
end

function Slots.Methods:Turn(mob): number
	local pack = mob.Config.pack or {}

	return self.Turns[mob] or pack.bites_per_turn or math.max(#(mob.Config.attack.animations or {}), 1)
end

function Slots.Methods:IsAttacker(mob): boolean
	return self.Slots[mob] ~= nil
end

function Slots.Methods:NoteAttack(mob)
	if self.Slots[mob] then
		self.Bites[mob] = (self.Bites[mob] or 0) + 1
	end
end

function Slots.Methods:ReleaseSlot(mob)
	self.Slots[mob] = nil
	self.Bites[mob] = nil
	self.Turns[mob] = nil
end

return Slots
