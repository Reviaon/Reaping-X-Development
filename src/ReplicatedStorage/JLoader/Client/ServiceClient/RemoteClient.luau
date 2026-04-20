local ClientSignal = {}

--@ Create a new client signal instance with the given remote
ClientSignal.new = function(remote)
	local self = setmetatable({
		Remote = remote,
		Connections = {}
	}, {__index = ClientSignal})
	return self
end

--@ Fire the signal to the server
function ClientSignal:Fire(...)
	self.Remote:FireServer(...)
end

--@ Connect a function to the client event
function ClientSignal:Connect(f)
	local con = self.Remote.OnClientEvent:Connect(f)
	table.insert(self.Connections, con)
	return con
end

--@ Destroy the client signal and disconnect all connections
function ClientSignal:Destroy()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self.Remote:Destroy()
end

return ClientSignal