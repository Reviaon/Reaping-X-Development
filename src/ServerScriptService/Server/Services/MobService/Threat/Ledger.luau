local Ledger = {}

function Ledger.new()
	return {
		Entries = {},
		Focus = nil,
		FocusSince = 0,
	}
end

function Ledger.Value(entry, decay: number, now: number): number
	if decay <= 0 then return entry.Amount end

	return entry.Amount * math.max(0, 1 - (now - entry.At) / decay)
end

function Ledger.Add(ledger, target: Model, amount: number, decay: number, now: number)
	local entry = ledger.Entries[target]

	if not entry then
		entry = { Amount = 0, At = now }
		ledger.Entries[target] = entry
	end

	entry.Amount = Ledger.Value(entry, decay, now) + amount
	entry.At = now
end

function Ledger.Clear(ledger)
	table.clear(ledger.Entries)
	ledger.Focus = nil
	ledger.FocusSince = 0
end

return Ledger
