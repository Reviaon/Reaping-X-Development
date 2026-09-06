local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local KnockbackHandler = Jloader.CreateHandler({ Name = script.Name })

local CombatService = Jloader.GetService("CombatService")
local KnockbackService = Jloader.GlobalFunctions.KnockbackService

function KnockbackHandler:Apply(victim, recipe)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return false end
	if not victim.Parent then return false end
	if typeof(recipe) ~= "table" then return false end

	return KnockbackService.Apply(victim, recipe)
end

function KnockbackHandler:Init()
	CombatService.Knockback:Connect(function(victim, recipe)
		KnockbackHandler:Apply(victim, recipe)
	end)
end

return KnockbackHandler
