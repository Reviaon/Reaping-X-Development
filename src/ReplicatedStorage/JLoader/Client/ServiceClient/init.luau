local ClientService = {}

local Shared = script.Parent.Parent.Shared

local RemoteClient = require(script.RemoteClient)
local HybridClient = require(script.HybridClient)

--@ Create a new client service instance with the given name and info
ClientService.new = function(name, info)
	local self = setmetatable({
		Name = name,
		Folder = Shared.Parent.Services:FindFirstChild(name)
	}, {__index = ClientService})

	--@ Reconstruct networked signals from the channel naming scheme. The channel
	--  must be computed identically to the server (serviceName|Type|signalName);
	--  no RemoteEvent instances are looked up — routing is via the ByteNet namespace.
	for Type, List in pairs(info._remotes) do
		for _, Name in ipairs(List) do
			local channel = name .. "|" .. Type .. "|" .. Name
			self[Name] = (Type == "Remote" and RemoteClient or HybridClient).new(channel)
		end
	end

	return self
end

return ClientService
