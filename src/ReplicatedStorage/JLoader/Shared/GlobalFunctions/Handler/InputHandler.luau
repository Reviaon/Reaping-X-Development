local InputHandler = {}

--@ Services
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--@ Variables
local InputDump = {}
local heldInputs = {};

--@ Libraries
local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local KeybindList = require(Libraries:WaitForChild("KeybindsLibrary"))

--@ Imports
function InputHandler.Init()
	InputDump = {}
	table.clear(heldInputs)
end

function InputHandler.Clear(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

function InputHandler:CheckKeys(...)
	for _, Key in {...} do
		local K = typeof(Key) == "string" and Enum.KeyCode[Key] or Key 
		if UserInputService:IsKeyDown(K) then
			return Key
		end
	end
end

function InputHandler:IsKeyDown(Key)
	return UserInputService:IsKeyDown(Key)
end

function InputHandler:IsMouseButtonDown(MouseButton)
	return UserInputService:IsMouseButtonPressed(MouseButton)
end

function InputHandler.HandleInput(Input, GPE, Began, actionTable, controller)
	local Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

	if not Character or UserInputService:GetFocusedTextBox() or GPE then return end
	if Character.Humanoid.Health <= 0 then heldInputs = {} return end

	local payload = controller or Character

	local Key = Input.KeyCode
	local InputType = Input.UserInputType

	local isKeyInWhitelist = table.find(KeybindList.WhiteList, Key) or table.find(KeybindList.WhiteList, InputType)

	if isKeyInWhitelist then
		local actionType = Began and "Began" or "Ended"
		local actionInfo = actionTable[actionType][Key] or actionTable[actionType][InputType]

		if actionInfo then
			if Began then
				heldInputs[Input] = actionInfo.canHold and actionInfo.action or nil
				if not next(heldInputs, next(heldInputs)) then
					task.spawn(function()
						while next(heldInputs) do
							for input, action in pairs(heldInputs) do
								if action then
									action(payload)
								end
							end
							RunService.Stepped:Wait()
						end
					end)
				end
				if not actionInfo.canHold then
					actionInfo.action(payload)
				end
			else
				heldInputs[Input] = nil
				actionInfo.action(payload)
			end
		end
	end
end

function InputHandler.BindInput(actionTable : {any}, connections : {any}, controller: any?)
	table.insert(connections, UserInputService.InputBegan:Connect(function(Input, GPE)
		InputHandler.HandleInput(Input, GPE, true, actionTable, controller)
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(Input, GPE)
		InputHandler.HandleInput(Input, GPE, false, actionTable, controller)
	end))
end

--@ Additional functions
function InputHandler:BindAction(actionName, inputTypes, actionFunction)
	ContextActionService:BindAction(actionName, actionFunction, false, table.unpack(inputTypes))
end

function InputHandler:UnbindAction(actionName)
	ContextActionService:UnbindAction(actionName)
end

function InputHandler:IsKeyHeld(Key)
	return UserInputService:IsKeyDown(Key)
end

function InputHandler:AreKeysDown(keys)
	for _, key in ipairs(keys) do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

function InputHandler:ListenForInput(inputType, callback)
	table.insert(InputDump, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == inputType then
			callback(input)
		end
	end))
end

function InputHandler:GetMousePosition()
	return UserInputService:GetMouseLocation()
end

return InputHandler
