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
local heldLoopRunning = false
local HOLD_REPEAT_DELAY = 0.25

--@ Libraries
local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local KeybindList = require(Libraries:WaitForChild("KeybindsLibrary"))

--@ Imports
function InputHandler.Init()
	InputDump = {}
	table.clear(heldInputs)
	heldLoopRunning = false
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
	local Key = Input.KeyCode
	local InputType = Input.UserInputType
	local heldKey = Key ~= Enum.KeyCode.Unknown and Key or InputType

	--@ Releases must ALWAYS clear the held state, before any gate below can
	--  swallow the event (GPE, focused textbox, missing Ended mapping), so a
	--  tapped canHold input can never keep repeating after release.
	if not Began then
		heldInputs[heldKey] = nil
	end

	--@ Never yield here: a press that arrives before the first character spawn
	--  must be dropped, not suspended on CharacterAdded — a suspended press
	--  resumes AFTER its release already cleared the held state and stores a
	--  phantom hold for a button that is no longer down.
	local Character = Players.LocalPlayer.Character
	if not Character then return end

	if Began and (UserInputService:GetFocusedTextBox() or GPE) then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then table.clear(heldInputs) return end

	local payload = controller or Character

	local isKeyInWhitelist = table.find(KeybindList.WhiteList, Key) or table.find(KeybindList.WhiteList, InputType)
	if not isKeyInWhitelist then return end

	local actionType = Began and "Began" or "Ended"
	local actionInfo = actionTable[actionType][Key] or actionTable[actionType][InputType]
	if not actionInfo then return end

	if Began then
		--@ Exactly one activation per physical press.
		actionInfo.action(payload)

		if actionInfo.canHold then
			heldInputs[heldKey] = {
				action = actionInfo.action,
				payload = payload,
				startedAt = os.clock(),
			}

			--@ Single shared repeat loop; re-invokes only after the input has
			--  been genuinely held past HOLD_REPEAT_DELAY, so taps never
			--  multi-fire or queue while hold-to-repeat stays intact.
			if not heldLoopRunning then
				heldLoopRunning = true
				task.spawn(function()
					while next(heldInputs) do
						RunService.Stepped:Wait()

						--@ Death fires no input event, so the loop itself must
						--  clear held state or a held input keeps acting on the
						--  corpse and carries into the respawn.
						local heldCharacter = Players.LocalPlayer.Character
						local heldHumanoid = heldCharacter and heldCharacter:FindFirstChildOfClass("Humanoid")
						if not heldHumanoid or heldHumanoid.Health <= 0 then
							table.clear(heldInputs)
							break
						end

						local now = os.clock()
						for _, held in pairs(heldInputs) do
							if now - held.startedAt >= HOLD_REPEAT_DELAY then
								--@ pcall so one erroring action cannot kill this
								--  thread and latch heldLoopRunning forever.
								local ok, err = pcall(held.action, held.payload)
								if not ok then
									warn("[InputHandler] Held action error:", err)
								end
							end
						end
					end
					heldLoopRunning = false
				end)
			end
		end
	else
		actionInfo.action(payload)
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

function InputHandler:GetKeysDown(keys)
	local _keyheld = nil

	for _, key in ipairs(keys) do
		if UserInputService:IsKeyDown(key) then
			_keyheld = key
			return _keyheld
		end
	end
	return _keyheld 
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
