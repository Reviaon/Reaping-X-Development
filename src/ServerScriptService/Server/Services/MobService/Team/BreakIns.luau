local Perception = require("../Senses/Perception")
local Geometry = require("./Geometry")

local BreakIns = {}

local random = Random.new()

function BreakIns.State()
	return {
		BreakIns = {},
		Assaults = setmetatable({}, { __mode = "k" }),
	}
end

function BreakIns.Forget(team, mob)
	team.BreakIns[mob] = nil
end

local function roll(value, whole: boolean?): number
	if typeof(value) ~= "table" then return value end

	return if whole then random:NextInteger(value[1], value[2]) else random:NextNumber(value[1], value[2])
end

BreakIns.Methods = {}

function BreakIns.Methods:TakeBreakIn(mob)
	local breakIn = self.BreakIns[mob]
	self.BreakIns[mob] = nil
	return breakIn
end

function BreakIns.Methods:BreakInCandidate(victim, attacker: Model)
	local root = Perception.RootOf(attacker)
	if not root then return nil end

	local best, bestDistance = nil, math.huge

	for member in self.Members do
		if member == victim or member.Dead or not member.Root or member.Target ~= attacker then continue end
		if self:IsAttacker(member) or member:IsDisabled() then continue end

		local distance = Geometry.Planar(member.Root.Position, root.Position)

		if distance < bestDistance then
			best, bestDistance = member, distance
		end
	end

	return best
end

function BreakIns.Methods:NoteAssault(victim, attacker: Model)
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

return BreakIns
