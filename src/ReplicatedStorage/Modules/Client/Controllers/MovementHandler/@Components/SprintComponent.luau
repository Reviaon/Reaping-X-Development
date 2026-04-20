--@ Strafing
local SprintComponent = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserinputService = game:GetService("UserInputService")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local CameraHandler = Jloader.GetHandler("CameraHandler")
local AnimatorService = GlobalFunctions.AnimatorService

local SprintSettings = {
	Trove = GlobalFunctions.Trove.new(),
}

function SprintComponent:Init(Character)
	if not Character then return end
	
end


function SprintComponent:Start(Character)
    if not Character then return end

    local Humanoid = Character:WaitForChild("Humanoid")
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
   
end

function SprintComponent:Reset()
	SprintSettings.Trove:Clean()
end

return SprintComponent
