local Server = {}

local Shared = script.Parent.Shared
local Load = require(Shared.Load)
local BaseService = require(script.BaseService)

--@ Server Constants
Server.GlobalFunctions = require(Shared.GlobalFunctions)
Server.Signal = Server.GlobalFunctions.Signal
Server.OnStart = Server.Signal.new()

local Services = {}
local Handlers = {}
local RawServices = {}

local Inited = false
Server.Started = false

local RepFolder = Instance.new("Folder")
RepFolder.Name = "Services"
RepFolder.Parent = script.Parent

--@ Stub function for creating a handler (not implemented)
Server.CreateHandler = function(list) end

--@ Stub function for initializing a handler (not implemented)
Server.InitHandler = function(module) end

--@ Stub function for getting a handler (not implemented)
Server.GetHandler = function(name) end

--@ Create a new service with the given properties
Server.CreateService = function(props)
	local Service = BaseService.new(props)
	Services[props.Name] = Service
	return Service
end

--@ Initialize a service module
Server.InitService = function(module)
	local Service = require(module)

	--@ Add shared functions to the service
	for Name, Item in pairs(Service.Shared) do
		if not Service.PackShared then
			Service[Name] = Item
		end

		if typeof(Item) ~= "function" then continue end
		table.insert(Service._sharedFns, Name)
	end

	--@ Create a RemoteFunction if there are shared functions
	if #Service._sharedFns > 0 then
		local Calls = Instance.new("RemoteFunction", Service.Folder)
		Calls.Name = "Calls"
		Calls.OnServerInvoke = function(plr, func, ...)
			return Service.Shared[func](Service, plr, ...)
		end
	end

	--@ Initialize the service if it has an Init method
	if Load.MethodExists(Service, "Init") then
		Service:Init()
	end
	return Service
end

--@ Retrieve a service by name, initializing it if necessary
Server.GetService = function(name)
	local Service = Services[name]
	if Service then return Service end

	if not Inited then
		for _, module in ipairs(RawServices) do
			if module.Name ~= name then continue end
			return Server.InitService(module)
		end
	end

	warn(`[{script.Parent.Name}]: '{name}' is not a valid Service: {debug.traceback()}`)
end

--@ Load and initialize services from a given list
Server.LoadServices = function(List)
	Load.AddRunners(List, RawServices, Server.InitService)
	Inited = true
end

--@ Start all services and fire the OnStart signal
Server.Load = function()
	Load.LoadRunners(Services)
	Server.Started = true
	Server.OnStart:Fire()
end

--@ Handle server invocation to get a service
local GetServiceRemote = Instance.new("RemoteFunction")
GetServiceRemote.Name = "GetService"
GetServiceRemote.Parent = Shared

GetServiceRemote.OnServerInvoke = function(plr, name)
	local Service = Server.GetService(name)
	return {
		Name = Service.Name,
		_sharedFns = Service._sharedFns,
		_remotes = Service._remotes,
		_shared = Service.Shared
	}
end

return Server
