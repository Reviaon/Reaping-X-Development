--@ Status Display Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local StatusDisplayHandler = Jloader.CreateHandler({ Name = script.Name })

local GlobalFunctions = Jloader.GlobalFunctions
local StatusService = GlobalFunctions.StatusService
local DebugService = GlobalFunctions.DebugService
local Config = require(script.Config)

local displays = {}
local localCharacter = nil

local function resolvePath(root, path)
	local found = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function detach(model)
	local display = displays[model]
	if not display then return end

	displays[model] = nil

	for _, connection in display.Connections do
		connection:Disconnect()
	end

	if display.Owned then
		display.Gui:Destroy()
	end
end

local function attach(model)
	if displays[model] then return end

	local gui = model:FindFirstChild(Config.DisplayName, true)
	local owned = gui == nil

	if owned then
		local template = resolvePath(ReplicatedStorage, Config.TemplatePath)
		local host = model:FindFirstChild("Head") or model.PrimaryPart

		if not template or not host then return end

		gui = template:Clone()
		gui.Parent = host
	end

	local label = gui:FindFirstChildWhichIsA("TextLabel", true)

	if not label then
		if owned then gui:Destroy() end
		return
	end

	gui.Enabled = DebugService.IsEnabled()

	displays[model] = {
		Gui = gui,
		Label = label,
		Owned = owned,
		Connections = {
			model.Destroying:Connect(function()
				detach(model)
			end),
		},
	}
end

local function textFor(model)
	local status = StatusService:GetDominantStatus(model)
	if not status then return Config.EmptyText end

	local remaining = StatusService:GetRemainingTime(model, status)

	return remaining and string.format(Config.TimedFormat, status, remaining) or status
end

local function isMob(model)
	return model:IsA("Model")
		and model:FindFirstChildOfClass("Humanoid") ~= nil
		and Players:GetPlayerFromCharacter(model) == nil
end

local function watchLiving(living)
	for _, child in living:GetChildren() do
		if isMob(child) then attach(child) end
	end

	living.ChildAdded:Connect(function(child)
		if isMob(child) then attach(child) end
	end)

	living.ChildRemoved:Connect(function(child)
		if child ~= localCharacter then detach(child) end
	end)
end

function StatusDisplayHandler:Load()
	local elapsed = 0

	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Config.RefreshInterval then return end
		elapsed = 0

		if not DebugService.IsEnabled() then return end

		for model, display in displays do
			display.Label.Text = textFor(model)
		end
	end)

	DebugService.Changed(function(enabled)
		for _, display in displays do
			display.Gui.Enabled = enabled
		end
	end)

	local living = workspace:WaitForChild(Config.LivingPath[1])

	for index = 2, #Config.LivingPath do
		living = living:WaitForChild(Config.LivingPath[index])
	end

	watchLiving(living)
end

function StatusDisplayHandler:InitCharacter(controller, isLocal)
	if not isLocal then return end

	if localCharacter then
		detach(localCharacter)
	end

	localCharacter = controller.Character

	if localCharacter then
		attach(localCharacter)
	end
end

return StatusDisplayHandler
