local Client = {}

local Shared = script.Parent.Shared
local Load = require(Shared.Load)

--@ Handlers
local BaseHandler = require(script.BaseHandler)
local BaseService = require(script.ServiceClient)

--@ Client Constants
Client.GlobalFunctions = require(Shared.GlobalFunctions)
Client.Signal = Client.GlobalFunctions.Signal

Client.OnStart = Client.Signal.new()

--@ Table Constants
local Handlers = {}
local Services = {}
local RawHandlers = {}

local Inited = false
Client.Started = false

local RepFolder = Instance.new("Folder")
RepFolder.Name = "Handlers"
RepFolder.Parent = script.Parent

--@ Create a new handler with the given properties
Client.CreateHandler = function(props)
	local Handler = BaseHandler.new(props)
	Handlers[props.Name] = Handler
	return Handler
end

--@ Initialize a handler module considering the AllowReinit property
Client.InitHandler = function(module)
	local Handler = require(module)

	if Load.MethodExists(Handler, "Init") and (not Handler.Inited or Handler.AllowReinit) then
		if Load.MethodExists(Handler, "Clean") then
			Handler:Clean()
		end

		Handler:Init()
		Handler.Inited = true
	end

	return Handler
end

--@ Retrieve a handler by name, initializing it if necessary
Client.GetHandler = function(name)
	local Handler = Handlers[name]
	if Handler then return Handler end

	if not Inited then
		for _, module in ipairs(RawHandlers) do
			if module.Name ~= name then continue end
			return Client.InitHandler(module)
		end
	end

	warn(`[{script.Parent.Name}]: '{name}' is not a valid Handler: {debug.traceback()}`)
end

--@ Retrieve a service by name, requesting server info if necessary
Client.GetService = function(name)
	local Service = Services[name]
	if Service then return Service end

	local ServerInfo = Shared:WaitForChild("GetService"):InvokeServer(name)
	Service = BaseService.new(name, ServerInfo)

	for _, Name in ipairs(ServerInfo._sharedFns) do
		Service[Name] = function(self, ...)
			return Service.Folder.Calls:InvokeServer(Name, ...)
		end
	end

	for i, v in pairs(ServerInfo._shared) do
		Service[i] = v
	end

	Services[name] = Service
	return Service
end

--@ Load and initialize handlers from a given list
Client.LoadHandlers = function(List)
	Load.AddRunners(List, RawHandlers, Client.InitHandler)
	Inited = true
end

--@ Start all handlers and fire the OnStart signal
Client.Load = function()
	Load.LoadRunners(Handlers)
	Client.Started = true
	Client.OnStart:Fire()
end

return Client
