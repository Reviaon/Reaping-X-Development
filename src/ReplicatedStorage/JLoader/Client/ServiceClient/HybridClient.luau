local HybridClient = {}

local Shared = script.Parent.Parent.Parent.Shared

local GlobalFunctions = require(Shared.GlobalFunctions)
local Signal = GlobalFunctions.Signal

local Remote = require(script.Parent.RemoteClient)

local Connection = {}
--@ Create a new connection for the hybrid client signals
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

--@ Create a new hybrid client instance for the given channel
HybridClient.new = function(channel)
	local self = setmetatable({
		_basic = Signal.new(),
		_remote = Remote.new(channel),
		Connections = {}
	}, {__index = HybridClient})
	return self
end

--@ Fire the signal on both basic and remote clients
function HybridClient:Fire(...)
	self._basic:Fire(...)
	self._remote:Fire(...)
end

--@ Connect a function to the hybrid client's signals
function HybridClient:Connect(f)
	local con = Connection.new(self, f)
	table.insert(self.Connections, con)
	return con
end

--@ Destroy the hybrid client and disconnect all connections
function HybridClient:Destroy()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self._remote:Destroy()
end

return HybridClient
