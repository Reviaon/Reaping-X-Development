local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local PositionHandler = Jloader.CreateHandler({ Name = script.Name })

local GlobalFunctions = Jloader.GlobalFunctions
local GarbageCollection = GlobalFunctions.Trove
local PositionService = GlobalFunctions.PositionService

PositionHandler.Trove = GarbageCollection.new()

local combatRelay = nil

local function getCombatRelay()
	combatRelay = combatRelay or Jloader.GetService("CombatService")
	return combatRelay
end

function PositionHandler:InitCharacter(controller, isLocal)
	if not isLocal then return end

	PositionHandler.Trove:Clean()

	local character = controller.Character
	if not character then return end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then return end

	local relay = getCombatRelay()
	if not relay then return end

	local lastAt, lastPosition = nil, nil

	PositionHandler.Trove:Add(RunService.Heartbeat:Connect(function()
		if not root.Parent then return end

		local settings = PositionService.Settings
		local now = os.clock()

		if lastAt and now - lastAt < settings.ReportInterval then return end

		local position = root.Position

		if lastPosition and (position - lastPosition).Magnitude < settings.MinDelta then return end

		lastAt = now
		lastPosition = position

		relay.ReportRoot:Fire(PositionService.Pack(root.CFrame))
	end))
end

function PositionHandler:Clean()
	PositionHandler.Trove:Destroy()
end

return PositionHandler
