--@ Status Display Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local StatusDisplayHandler = Jloader.CreateHandler({ Name = script.Name })
StatusDisplayHandler.Morphs = true

local GlobalFunctions = Jloader.GlobalFunctions
local StatusService = GlobalFunctions.StatusService
local DebugService = GlobalFunctions.DebugService
local Config = require("@self/Config")

local displays = {}
local waiting = {}
local localCharacter = nil

local function resolvePath(root, path)
	local found = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function hostOf(model)
	for _, name in Config.HostParts do
		local part = model:FindFirstChild(name)

		if part then
			return part
		end
	end

	return model.PrimaryPart
end

local function stopWaiting(model)
	local connection = waiting[model]

	if connection then
		waiting[model] = nil
		connection:Disconnect()
	end
end

local function detach(model)
	stopWaiting(model)

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

	stopWaiting(model)

	local gui = model:FindFirstChild(Config.DisplayName, true)
	local owned = gui == nil

	if owned then
		local template = resolvePath(ReplicatedStorage, Config.TemplatePath)
		local host = hostOf(model)

		if not template or not host then return end

		gui = template:Clone()
		gui.Parent = host
	end

	local label = gui:FindFirstChild(Config.StatusLabel, true) or gui:FindFirstChildWhichIsA("TextLabel", true)
	local overhead = gui:FindFirstChild(Config.OverheadLabel, true)

	if not label then
		if owned then gui:Destroy() end
		return
	end

	gui.Enabled = DebugService.IsEnabled()

	displays[model] = {
		Gui = gui,
		Label = label,
		Overhead = if overhead and overhead:IsA("TextLabel") and overhead ~= label then overhead else nil,
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

local function consider(model)
	if displays[model] or waiting[model] then return end
	if not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then return end

	if model:FindFirstChildOfClass("Humanoid") and hostOf(model) then
		attach(model)
		return
	end

	waiting[model] = model.ChildAdded:Connect(function()
		if model:FindFirstChildOfClass("Humanoid") and hostOf(model) then
			attach(model)
		end
	end)
end

local function watchLiving(living)
	for _, child in living:GetChildren() do
		consider(child)
	end

	living.ChildAdded:Connect(consider)

	living.ChildRemoved:Connect(function(child)
		if child ~= localCharacter then
			detach(child)
		end
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

			if display.Overhead then
				local line = model:GetAttribute(DebugService.Settings.Overhead)

				display.Overhead.Text = line or ""
				display.Overhead.Visible = line ~= nil
			end
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
