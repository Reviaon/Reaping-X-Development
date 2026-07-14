local Server = {}

local Shared = script.Parent.Shared
local Load = require(Shared.Load)
local BaseService = require(script.BaseService)

--@ Server Constants
Server.GlobalFunctions = require(Shared.GlobalFunctions)
Server.Signal = Server.GlobalFunctions.Signal
Server.OnStart = Server.Signal.new()

--@ Networking router (ByteNet). Requiring it here defines the shared namespace
--  and starts the server-side listeners before any service registers channels.
local Net = Server.GlobalFunctions.Net

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

	--@ Register an RPC channel for the service's shared functions. Only names in
	--  the declared _sharedFns allow-list are callable, and rawget bypasses the
	--  Shared __index=self / __index=ServerService chain so a client cannot reach
	--  arbitrary server methods (SpawnVisual, Init, new, ...).
	if #Service._sharedFns > 0 then
		Net.onRpc(Service.Name .. "|Calls", function(plr, func, ...)
			if typeof(func) ~= "string" or not table.find(Service._sharedFns, func) then
				return nil
			end
			local fn = rawget(Service.Shared, func)
			if typeof(fn) ~= "function" then return nil end
			return fn(Service, plr, ...)
		end)
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

--@ Strip function values from a service's Shared table before it crosses the
--  network. Function *names* travel in _sharedFns and are re-bound to RPC calls
--  on the client; the raw functions themselves cannot be serialized. Recurses so
--  a function nested inside a Shared table value cannot slip through and crash the
--  RPC response serialization; `seen` guards against cyclic tables.
local function packSharedValues(shared, seen)
	seen = seen or {}
	--@ Memoize input table -> cleaned copy so cyclic refs terminate AND aliased
	--  sub-tables (same table under two keys) resolve to one cleaned copy instead
	--  of being dropped on the second visit.
	if seen[shared] then
		return seen[shared]
	end
	local out = {}
	seen[shared] = out
	for k, v in pairs(shared) do
		local t = typeof(v)
		if t == "function" then
			--@ dropped: not serializable, and never RPC-bound
		elseif t == "table" then
			out[k] = packSharedValues(v, seen)
		else
			out[k] = v
		end
	end
	return out
end

--@ Handle service discovery requests over ByteNet RPC
Net.onRpc("__JLoader_GetService", function(plr, name)
	local Service = Server.GetService(name)
	if not Service then return nil end
	return {
		Name = Service.Name,
		_sharedFns = Service._sharedFns,
		_remotes = Service._remotes,
		_shared = packSharedValues(Service.Shared),
	}
end)

return Server
