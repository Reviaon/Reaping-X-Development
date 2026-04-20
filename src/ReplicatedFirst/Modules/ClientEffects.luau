--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)

local GlobalFunctions = Jloader.GlobalFunctions
local EffectService = Jloader.GetService("EffectService")

local ClientEffects = Jloader.CreateHandler({
	Name = script.Name,
})

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")

--@ Constants
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Effects = Modules:WaitForChild("Effects")
local Libraries = Modules:WaitForChild("Libraries")

local VFX = {}

--@ Load VFX Modules
function ClientEffects:LoadEffects()
	for _, Visual in Effects:GetDescendants() do
		if not Visual:IsA("ModuleScript") then continue end
		VFX[Visual.Name] = require(Visual)
	end
end

ClientEffects:LoadEffects()

--@ Start Method
function ClientEffects:Init()	
	EffectService.CreateVisual:Connect(function(Data)
		if typeof(Data) ~= "table" then return end

		if not Data.Info then warn("Fire Client Remote With A Info Table.") return end		
		if not Data.Effect then warn("Invalid Effect.") return end

		if Data.Method then
			local EffectMod = VFX[Data.Effect]

			if EffectMod[Data.Method] then
				EffectMod[Data.Method](Data.Info)
			end;

			return
		end

		local EffectMod = VFX[Data.Effect]
		if not EffectMod then warn("Issue Requiring Effect Mod") end

		EffectMod(Data.Info)
	end)	
end

return ClientEffects
