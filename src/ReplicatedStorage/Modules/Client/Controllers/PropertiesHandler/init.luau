--@ Property Handler
local Jloader = require(game.ReplicatedStorage.JLoader)
local PropertyHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")

local GlobalFunctions = Jloader.GlobalFunctions
local StatusService = GlobalFunctions.StatusService
local Trove = GlobalFunctions.Trove

local StatusStates = StatusService:GetStatesTable()

--@ Default base stats when no status overrides are active
local BASE_WALK_SPEED = 14
local BASE_JUMP_POWER = 50
local SPEED_LERP_ALPHA = 8 

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function applyHumanoidProperties(controller)
	local Character = controller.Character
	local Humanoid  = controller.Humanoid
	if not Character or not Humanoid then return end

	local walkSpeed, jumpPower, highestPriority = BASE_WALK_SPEED, BASE_JUMP_POWER, -math.huge

	for attrName in Character:GetAttributes() do
		local statusData = StatusStates[attrName]
		if statusData then
			local priority = statusData.Priority or 0
			if priority > highestPriority then
				highestPriority = priority

				if attrName == "NoAutoRotate" then
					Humanoid.AutoRotate = false
				end

				walkSpeed = statusData.WalkSpeed or walkSpeed
				jumpPower = statusData.JumpPower or jumpPower
			end
		end
	end

	controller:Set("GoalSpeed", walkSpeed)
	Humanoid.JumpPower = math.max(jumpPower, 0)

	if jumpPower <= 0 and walkSpeed < BASE_WALK_SPEED then
		Humanoid.Jump = false
	end
end

local function walkUpdate(controller, dt)
	local Humanoid = controller.Humanoid
	if not Humanoid then return end

	local goalSpeed = controller:Get("GoalSpeed") or BASE_WALK_SPEED

	Humanoid.WalkSpeed = lerp(
		Humanoid.WalkSpeed,
		goalSpeed,
		math.clamp(SPEED_LERP_ALPHA * dt, 0, 1)
	)
end

function PropertyHandler:InitCharacter(controller)
	local Character = controller.Character
	if not Character then return end

	local trove = Trove.new()

	applyHumanoidProperties(controller)

	trove:Connect(Character.AttributeChanged, function()
		applyHumanoidProperties(controller)
	end)

	trove:Connect(RunService.RenderStepped, function(dt)
		walkUpdate(controller, dt)
	end)

	trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			trove:Clean()
		end
	end)
end

return PropertyHandler
