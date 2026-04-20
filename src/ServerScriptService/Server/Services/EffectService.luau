--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)
local GlobalFunctions = Jloader.GlobalFunctions

local EffectService = Jloader.CreateService({
	Name = script.Name,
	Signals = {Remote = {"CreateVisual"}}
})

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")

--@ Constants
local components = {}

function EffectService:SpawnVisual(Player, Args)
	self.CreateVisual:FireAll(Args);
end;

function EffectService:Init()
	for _, modulesscript in script:GetDescendants() do
		if modulesscript:IsA("ModuleScript") then
			components[modulesscript.Name] = require(modulesscript);
		end;
	end;

	local Tasks = {
		["SpawnVisual"] = self.SpawnVisual,
	};

	self.CreateVisual:Connect(function(Player, TaskName, ...)
		local Func = Tasks[TaskName];
		if not Func then return end;
		Func(self, Player, ...)
	end)
end

return EffectService
