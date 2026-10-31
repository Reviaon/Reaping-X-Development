local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local PairSceneHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")

function PairSceneHandler:Load()
	local PairSceneService = Jloader.GlobalFunctions.PairSceneService

	RunService.PreRender:Connect(PairSceneService.HoldAnchors)
end

return PairSceneHandler
