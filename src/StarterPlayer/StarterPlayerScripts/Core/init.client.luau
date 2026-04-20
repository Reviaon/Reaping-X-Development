--@ Core Client Bootstrap
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JLoader = require(ReplicatedStorage.JLoader)

--@ Collect top-level ModuleScripts from the Client controllers folder
local Controllers = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client")
local ControllerList = {}

for _, module in ipairs(Controllers:GetChildren()) do
	if module:IsA("ModuleScript") then
		table.insert(ControllerList, module)
	elseif module:IsA("Folder") then
		-- One level deep for grouped controllers (e.g. Controllers/)
		for _, child in ipairs(module:GetChildren()) do
			if child:IsA("ModuleScript") then
				table.insert(ControllerList, child)
			end
		end
	end
end

--@ Load and start all controllers
JLoader.LoadHandlers(ControllerList)
JLoader.Load()
