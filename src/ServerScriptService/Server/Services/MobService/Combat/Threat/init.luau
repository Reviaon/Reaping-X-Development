local Perception = require("../Senses/Perception")
local Ledger = require("@self/Ledger")
local Select = require("@self/Select")

local Threat = {}

Threat.Ledger = Ledger.new

local function settingsOf(mob)
	return mob.Config.threat
end

function Threat.Hit(mob, attacker: Model, damage: number?)
	local settings = settingsOf(mob)
	if not settings or not Perception.IsValidTarget(attacker) then return end

	local amount = settings.provoke + math.max(damage or 0, 0) * settings.damage

	Ledger.Add(mob.Ledger, attacker, amount, settings.decay, os.clock())
end

function Threat.Focus(mob): Model?
	local settings = settingsOf(mob)
	if not settings or not mob.Ledger then return nil end

	return Select.Focus(mob, mob.Ledger, settings, os.clock())
end

function Threat.Score(mob, target: Model): number
	local settings = settingsOf(mob)
	if not settings or not mob.Ledger then return 0 end

	return Select.Score(mob, mob.Ledger, target, settings, os.clock())
end

function Threat.Release(mob)
	if mob.Ledger then
		mob.Ledger.Focus = nil
		mob.Ledger.FocusSince = 0
	end
end

function Threat.Clear(mob)
	if mob.Ledger then
		Ledger.Clear(mob.Ledger)
	end
end

function Threat.Dump(mob): { { Target: Model, Score: number, Focus: boolean } }
	local rows = {}
	if not mob.Ledger then return rows end

	for target in mob.Ledger.Entries do
		table.insert(rows, { Target = target, Score = Threat.Score(mob, target), Focus = mob.Ledger.Focus == target })
	end

	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)

	return rows
end

return Threat
