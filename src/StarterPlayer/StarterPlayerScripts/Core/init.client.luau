--@ Core Client Bootstrap
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JLoader = require(ReplicatedStorage.JLoader)

local Controllers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client")
local ControllerList = {}

local function collectControllers(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(ControllerList, child)
		elseif child:IsA("Folder") then
			collectControllers(child)
		end
	end
end

collectControllers(Controllers)

--@ Include the ReplicatedFirst effect handler so its firing gets initialized
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local EffectsHandler = ReplicatedFirst:WaitForChild("Modules"):WaitForChild("ClientEffects")
table.insert(ControllerList, EffectsHandler)

--@ Load and start all controllers
JLoader.LoadHandlers(ControllerList)
JLoader.Load()
