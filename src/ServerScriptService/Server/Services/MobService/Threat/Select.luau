local Perception = require("../Perception")
local Ledger = require("./Ledger")
local Reach = require("./Reach")

local Select = {}

local function proximity(mob, root: BasePart, settings): number
	local range = mob.Config.detect_range
	if not settings.proximity or not range or range <= 0 then return 0 end

	local distance = (root.Position - mob.Root.Position).Magnitude

	return settings.proximity * math.clamp(1 - distance / range, 0, 1)
end

function Select.Score(mob, ledger, target: Model, settings, now: number): number
	local entry = ledger.Entries[target]
	local root = Perception.RootOf(target)
	if not entry or not root or not mob.Root then return 0 end

	local value = Ledger.Value(entry, settings.decay, now)
	if value <= 0 then return 0 end

	return (value + proximity(mob, root, settings)) * Reach.Scale(mob, target, entry, root, settings, now)
end

function Select.Focus(mob, ledger, settings, now: number): Model?
	local incumbent = ledger.Focus
	local best, bestScore, incumbentScore = nil, 0, nil

	for target in ledger.Entries do
		local score = if Perception.IsValidTarget(target) then Select.Score(mob, ledger, target, settings, now) else 0

		if score <= 0 then
			ledger.Entries[target] = nil
			continue
		end

		if target == incumbent then
			incumbentScore = score
		end

		if score > bestScore then
			best, bestScore = target, score
		end
	end

	if not best then
		ledger.Focus = nil
		return nil
	end

	if incumbentScore and best ~= incumbent then
		local dwelling = now - ledger.FocusSince < settings.min_dwell
		local beaten = bestScore >= incumbentScore * (1 + settings.switch_margin)

		if dwelling or not beaten then return incumbent end
	end

	if best ~= incumbent then
		ledger.Focus = best
		ledger.FocusSince = now
	end

	return best
end

return Select
