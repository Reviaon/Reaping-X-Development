--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)
local GlobalFunctions = Jloader.GlobalFunctions

local ActionService = Jloader.CreateService({
	Name = script.Name,
	Signals = {Remote = {"Task"}}
})

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")

--@ Constants
local components = {}

function ActionService:Request(Player, Args)		
	if Args.Configuration and components[Args.Configuration] then
		
		components[Args.Configuration]:Start(Player.Character, Args);
	end;
end;

function ActionService:Init()
	for _, modulesscript in script:GetDescendants() do
		if modulesscript:IsA("ModuleScript") then
			components[modulesscript.Name] = require(modulesscript);
		end;
	end;

	local Tasks = {
		["Request"] = self.Request,
	};

	self.Task:Connect(function(Player, TaskName, ...)
		local Func = Tasks[TaskName];
		if not Func then return end;
		Func(self, Player, ...);
	end);
end

return ActionService
