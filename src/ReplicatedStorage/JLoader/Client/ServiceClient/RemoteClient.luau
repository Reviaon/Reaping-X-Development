--@ RemoteClient — client-side signal, now backed by ByteNet via Net.
--  Public API is unchanged (:Fire/:Connect), only the transport differs.
--  Each instance owns a stable `Channel` string matching the server side.

local Shared = script.Parent.Parent.Parent.Shared
local Net = require(Shared.GlobalFunctions).Net

local ClientSignal = {}
ClientSignal.__index = ClientSignal

--@ Create a new client signal for the given channel
ClientSignal.new = function(channel: string)
	local self = setmetatable({
		Name = channel,
		Channel = channel,
		Connections = {},
	}, ClientSignal)
	return self
end

--@ Fire the signal to the server
function ClientSignal:Fire(...)
	Net.fireServer(self.Channel, ...)
end

--@ Connect a function to the signal. Handler receives (...).
function ClientSignal:Connect(f)
	local con = Net.onEvent(self.Channel, f)
	table.insert(self.Connections, con)
	return con
end

--@ Disconnect every connection made through this signal
function ClientSignal:Disconnect()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self.Connections = {}
end

ClientSignal.Destroy = ClientSignal.Disconnect

return ClientSignal
