local Reservations = {}

function Reservations.State()
	return { Reservations = {} }
end

Reservations.Methods = {}

function Reservations.Methods:Reserve(target: Model, key: string, seconds: number): boolean
	local reservations = self.Reservations[target]
	local now = os.clock()

	if reservations and (reservations[key] or 0) > now then return false end

	reservations = reservations or {}
	reservations[key] = now + seconds
	self.Reservations[target] = reservations

	return true
end

function Reservations.Methods:Reserved(target: Model, key: string): boolean
	local reservations = self.Reservations[target]
	return reservations ~= nil and (reservations[key] or 0) > os.clock()
end

return Reservations
