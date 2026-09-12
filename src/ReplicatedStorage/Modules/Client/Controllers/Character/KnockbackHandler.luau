local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local KnockbackHandler = Jloader.CreateHandler({ Name = script.Name })

local CombatService = Jloader.GetService("CombatService")
local KnockbackService = Jloader.GlobalFunctions.KnockbackService
local RagdollService = Jloader.GlobalFunctions.RagdollService
local TrajectoryService = Jloader.GlobalFunctions.TrajectoryService

function KnockbackHandler:Apply(victim, recipe)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return false end
	if not victim.Parent then return false end
	if typeof(recipe) ~= "table" then return false end

	return KnockbackService.Apply(victim, recipe)
end

function KnockbackHandler:Launch(victim, velocity, landing, motion)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return false end
	if typeof(velocity) ~= "Vector3" then return false end

	KnockbackService.Cancel(victim)
	TrajectoryService.DrawLaunch(victim, velocity, landing)

	if typeof(landing) == "table" and typeof(landing.At) == "number" then
		task.delay(TrajectoryService.LandingDelay(victim, landing), function()
			TrajectoryService.Landed:Fire(victim, landing)
		end)
	end

	if victim ~= Players.LocalPlayer.Character then return true end

	return RagdollService.Launch(victim, velocity, motion)
end

function KnockbackHandler:InitCharacter(controller, isLocal)
	if not isLocal or not controller.Character then return end

	RagdollService.Watch(controller.Character)
end

function KnockbackHandler:Init()
	CombatService.Knockback:Connect(function(victim, recipe)
		KnockbackHandler:Apply(victim, recipe)
	end)

	CombatService.Launch:Connect(function(victim, velocity, landing, motion)
		KnockbackHandler:Launch(victim, velocity, landing, motion)
	end)
end

return KnockbackHandler
