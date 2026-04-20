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

	--@ Initialize remotes and hybrid clients for the service
	for Type, List in pairs(info._remotes) do
		for _, Name in ipairs(List) do
			local Remote = self.Folder[Type]:FindFirstChild(Name)
			self[Name] = (Type == "Remote" and RemoteClient or HybridClient).new(Remote)
		end
	end

	return self
end

return ClientService
