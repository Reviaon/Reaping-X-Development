local HybridSignal = {}

local Shared = script.Parent.Parent.Parent.Shared

local GlobalFunctions = require(Shared.GlobalFunctions)
local Signal = GlobalFunctions.Signal

local Remote = require(script.Parent.RemoteServer)

--@ Create a new connection for the hybrid signal
local Connection = {}
Connection.new = function(signal, fn)
	signal._basic:Connect(fn)
	signal._remote:Connect(fn)
	return setmetatable({_signal = signal}, {__index = Connection})
end

--@ Disconnect the connection from both basic and remote signals
function Connection:Disconnect()
	for i, con in ipairs(self._signal.Connections) do
		if con ~= self then continue end
		table.remove(self._signal.Connections, i)
	end

	self._signal._basic:Disconnect()
	self._signal._remote:Disconnect()
end

--@ Create a new hybrid signal instance for the given channel
HybridSignal.new = function(channel)
	local self = setmetatable({
		Name = channel or "HybridEvent",
		Connections = {}
	}, {__index = HybridSignal})

	self._basic = Signal.new()
	self._remote = Remote.new(self.Name)
	return self
end

--@ Fire the signal to a specific player
function HybridSignal:Fire(plr, ...)
	self._basic:Fire(plr, ...)
	self._remote:Fire(plr, ...)
end

--@ Fire the signal to all players
function HybridSignal:FireAll(...)
	self._basic:Fire(...)
	self._remote:FireAll(...)
end

--@ Fire the signal to all players except the specified player
function HybridSignal:FireExcept(plr, ...)
	self._basic:Fire(plr, ...)
	self._remote:FireExcept(plr, ...)
end

--@ Fire the signal to players that meet the filter criteria
function HybridSignal:FireFilter(filter, ...)
	self._basic:Fire(...)
	self._remote:FireFilter(filter, ...)
end

--@ Connect a function to the hybrid signal
function HybridSignal:Connect(f)
	local con = Connection.new(self, f)
	table.insert(self.Connections, con)
	return con
end

--@ Destroy the hybrid signal and disconnect all connections
function HybridSignal:Destroy()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self._remote:Destroy()
end

return HybridSignal