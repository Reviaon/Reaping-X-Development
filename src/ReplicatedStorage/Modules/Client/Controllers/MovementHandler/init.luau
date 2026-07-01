--@ Start
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local MovementHandler = Jloader.CreateHandler({Name = script.Name})

--@ Services
local RunService = game:GetService("RunService")

--@ Imports
local GlobalFunctions = Jloader.GlobalFunctions
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

local inputConnections = {};

local inputActions = {
	Began = {
		[Enum.KeyCode.Q] = {
			canHold = false,
			action = function(controller)
				MovementHandler.components["DiveComponent"]:Activate(controller)
			end,
		},
		[Enum.KeyCode.LeftShift] = {
			canHold = true,
			action = function(controller)
				MovementHandler.components["SprintComponent"]:Activate(controller)
			end,
		},
		[Enum.KeyCode.C] = {
			canHold = false,
			action = function(controller)
				MovementHandler.components["CrouchComponent"]:Activate(controller)
			end,
		},
	},
	Ended = {
		[Enum.KeyCode.C] = {
			canHold = false;
			action = function(controller)
				MovementHandler.components["CrouchComponent"]:Deactivate(controller)
			end;
		},
		[Enum.KeyCode.LeftShift] = {
			canHold = true,
			action = function(controller)
				MovementHandler.components["SprintComponent"]:Deactivate(controller)
			end,
		},
	}
}

--@ Bind Input
function MovementHandler:Init()
	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections, ClientController);
end

function MovementHandler:InitCharacter(controller)
	MovementHandler.Trove:Destroy()
	MovementHandler.Trove = GarbageCollection.new()

	MovementHandler.components["TiltComponent"]:Init(controller)
	MovementHandler.components["StrafeComponent"]:Init(controller)

	MovementHandler.Trove:Connect(RunService.RenderStepped, function(DeltaTime)
		MovementHandler.components["TiltComponent"]:Update(DeltaTime)
	end)

	local Character = controller.Character

	MovementHandler.Trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			controller:ClearCharacter()
		end
	end)
end

function MovementHandler:Clean() 
	MovementHandler.Trove:Destroy()
end

return MovementHandler