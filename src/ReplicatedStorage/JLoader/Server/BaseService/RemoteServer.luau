local ServerSignal = {}

--@ Create a new server signal instance with the given parent and name
ServerSignal.new = function(parent, name)
	local self = setmetatable({
		Name = name or "RemoteEvent",
		Remote = Instance.new("RemoteEvent", parent),
		Connections = {}
	}, {__index = ServerSignal})
	self.Remote.Name = self.Name
	return self
end

--@ Fire the signal to a specific player
function ServerSignal:Fire(plr, ...)
	self.Remote:FireClient(plr, ...)
end

--@ Fire the signal to all players
function ServerSignal:FireAll(...)
	self.Remote:FireAllClients(...)
end

--@ Fire the signal to all players except the specified player
function ServerSignal:FireExcept(plr, ...)
	for _, p in ipairs(game.Players:GetPlayers()) do
		if p == plr or p.Name == plr then continue end
		self:Fire(p, ...)
	end
end

--@ Fire the signal to players that meet the filter criteria
function ServerSignal:FireFilter(filter, ...)
	filter = filter or function() return true end
	for _, p in ipairs(game.Players:GetPlayers()) do
		if not filter(p) then continue end
		self:Fire(p, ...)
	end
end

--@ Connect a function to the server signal
function ServerSignal:Connect(f)
	local con = self.Remote.OnServerEvent:Connect(f)
	table.insert(self.Connections, con)
	return con
end

--@ Destroy the server signal and disconnect all connections
function ServerSignal:Destroy()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self.Remote:Destroy()
end

return ServerSignal