local ServerService = {}

local Shared = script.Parent.Parent.Shared

local GlobalFunctions = require(Shared.GlobalFunctions)
local Signal = GlobalFunctions.Signal

local RemoteServer = require(script.RemoteServer)
local HybridServer = require(script.HybridServer)

--@ Create a new server service instance with the given template
ServerService.new = function(template)
	local self = setmetatable(template, {__index = ServerService})
	self.Priority = template.Priority or 1
	self.Signals = template.Signals or {}
	self.Shared = template.Shared or {}
	self.PackShared = template.PackShared

	self._sharedFns = {}
	self._remotes = {Remote = {}, Hybrid = {}}
	setmetatable(self.Shared, {__index = self})

	--@ Create a folder for the service within the shared parent
	local Folder = Instance.new("Folder", Shared.Parent.Services)
	Folder.Name = self.Name
	self.Folder = Folder

	--@ Initialize signals for the service.
	--  Networked signals (Remote / Hybrid) are keyed by a stable channel string
	--  that the client recomputes identically; no per-signal RemoteEvent is
	--  created anymore — everything routes through the shared ByteNet namespace.
	for Type, List in pairs(self.Signals) do
		if #List == 0 then continue end

		if Type == "Basic" then
			for _, Name in ipairs(List) do
				self[Name] = Signal.new()
			end
		else
			for _, Name in ipairs(List) do
				local channel = self.Name .. "|" .. Type .. "|" .. Name
				self[Name] = (Type == "Remote" and RemoteServer or HybridServer).new(channel)
				table.insert(self._remotes[Type], Name)
			end
		end
	end

	return self
end

return ServerService