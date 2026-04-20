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
		[Enum.KeyCode.Space] = {
			canHold = false,
			action = function(Character : Model)				
			end,
		},
		[Enum.KeyCode.Q] = {
			canHold = false;
			action = function(Character : Model)				
			end;
		},
		[Enum.KeyCode.W] = {
			canHold = false;
			action = function(Character : Model)
			end;
		},
		
		[Enum.KeyCode.LeftShift] = {
			canHold = false;
			action = function(Character : Model)
			end;
		},
	},
	Ended = {
		[Enum.KeyCode.Space] = {
			canHold = false;
			action = function(Character : Model)
				
			end;
		},
		[Enum.KeyCode.W] = {
			canHold = false;
			action = function(Character : Model)
				
			end;
		},
	}
}

--@ Bind Input
function MovementHandler:Init()
	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections);
end

function MovementHandler:InitCharacter()
	local Player = Players.LocalPlayer;
	
	local Character = Player.Character or Player.CharacterAdded:Wait();
	local HumanoidRootPart = Character.HumanoidRootPart
	local Humanoid = Character:WaitForChild("Humanoid")
		
	MovementHandler.components["TiltComponent"]:Init(Character);
	MovementHandler.components["StrafeComponent"]:Init(Character);

	MovementHandler.Trove:Connect(RunService.RenderStepped, function(DeltaTime)
		MovementHandler.components["TiltComponent"]:Update(DeltaTime);		
	end)
end

function MovementHandler:Clean() 
	MovementHandler.Trove:Destroy()
end

return MovementHandler