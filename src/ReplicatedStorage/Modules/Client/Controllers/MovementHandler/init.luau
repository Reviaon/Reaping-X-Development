--@ Start
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local MovementHandler = Jloader.CreateHandler({Name = script.Name})

--@ Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--@ Libraries
local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local KeybindList = require(Libraries:WaitForChild("KeybindsLibrary"))

--@ Imports
local GlobalFunctions = Jloader.GlobalFunctions
local CooldownService = GlobalFunctions.CooldownService
local StatusService = GlobalFunctions.StatusService
local RaycastService = GlobalFunctions.RaycastService

local InputHandler = GlobalFunctions.InputHandler
local GarbageCollection = GlobalFunctions.Trove
local ClientController = GlobalFunctions.ClientController

--@ Movement Controller Constants:
MovementHandler.components = {};
MovementHandler.Trove = GarbageCollection.new()

for _, controller: ModuleScript in script:GetDescendants() do
	if controller:IsA("ModuleScript") and not controller:GetAttribute("AutoInit") then
		MovementHandler.components[controller.Name] = require(controller)
	end
end

local heldInputs = {}
local inputConnections = {};

local inputActions = {
	Began = {
		[Enum.KeyCode.LeftShift] = {
			canHold = true,
			action = function()
				MovementHandler.components["SprintComponent"]:Activate(ClientController)
			end,
		},
		[Enum.KeyCode.C] = {
			canHold = false,
			action = function()
				MovementHandler.components["CrouchComponent"]:Activate(ClientController)
			end,
		},
	},
	Ended = {
		[Enum.KeyCode.C] = {
			canHold = false;
			action = function()
				MovementHandler.components["CrouchComponent"]:Deactivate(ClientController)
			end;
		},
		[Enum.KeyCode.LeftShift] = {
			canHold = true,
			action = function()
				MovementHandler.components["SprintComponent"]:Deactivate(ClientController)
			end,
		},
	}
}

--@ Bind Input
function MovementHandler:Init()
	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections);
end

function MovementHandler:InitCharacter()
	local Player = Players.LocalPlayer

	local function onCharacter(Character: Model)
		ClientController:SetCharacter(Character)

		MovementHandler.Trove:Destroy()
		MovementHandler.Trove = GarbageCollection.new()

		MovementHandler.components["TiltComponent"]:Init(ClientController)
		MovementHandler.components["StrafeComponent"]:Init(ClientController)

		MovementHandler.Trove:Connect(RunService.RenderStepped, function(DeltaTime)
			MovementHandler.components["TiltComponent"]:Update(DeltaTime)
		end)

		MovementHandler.Trove:Connect(Character.AncestryChanged, function()
			if not Character:IsDescendantOf(game) then
				ClientController:ClearCharacter()
			end
		end)
	end

	local Character = Player.Character or Player.CharacterAdded:Wait()
	onCharacter(Character)

	Player.CharacterAdded:Connect(onCharacter)
end

function MovementHandler:Clean() 
	MovementHandler.Trove:Destroy()
end

return MovementHandler