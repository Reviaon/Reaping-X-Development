--@ Strafing
local CrouchComponent = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserinputService = game:GetService("UserInputService")

--@ Imports
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local CameraHandler = Jloader.GetHandler("CameraHandler")
local AnimatorService = GlobalFunctions.AnimatorService
local StatusService = GlobalFunctions.StatusService

local CrouchSettings = {
	Trove = GlobalFunctions.Trove.new(),
}

function CrouchComponent:Init()	
end
 

function CrouchComponent:Activate(Character)
    if not Character then return end

    local Humanoid = Character:WaitForChild("Humanoid")
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    if StatusService:CheckStatus(Character, "Crouching") then
        return
    end

    StatusService:AddStatus(Character, "Crouching")
end

function CrouchComponent:Deactivate(Character)
    
    if StatusService:CheckStatus(Character, "Crouching") then
        StatusService:RemoveStatus(Character, "Crouching")
    end
end

return CrouchComponent
