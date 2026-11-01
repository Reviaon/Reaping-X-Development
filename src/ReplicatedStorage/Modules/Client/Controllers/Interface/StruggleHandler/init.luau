local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local StruggleHandler = Jloader.CreateHandler({ Name = script.Name })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local StruggleLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/StruggleLibrary")
local Indicator = require("@self/Indicator")

local current = nil
local relay = nil

local function template(): Instance?
	local found = ReplicatedStorage

	for _, segment in StruggleLibrary.Template do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function press(dot)
	if not current or dot.Done then return end

	dot.Done = true

	local now = workspace:GetServerTimeNow()
	local data = dot.Data

	relay.Click:Fire(current.Id, data.Id, now)

	if now >= data.HitFrom and now <= data.HitUntil then
		dot.Handle.Hit()
	else
		dot.Handle.Miss()
	end
end

local function spawnDot(data)
	local dot = { Data = data, Done = false }

	dot.Handle = Indicator.new(current.Bubble, current.Board, data, current.Profile, function()
		press(dot)
	end)

	dot.Handle.Appear()
	table.insert(current.Live, dot)
end

local function stop(id: number?)
	if not current or (id and current.Id ~= id) then return end

	for _, dot in current.Live do
		dot.Handle.Destroy()
	end

	current.Gui:Destroy()
	current = nil
end

local function step(dt: number)
	if not current then return end

	local character = Players.LocalPlayer.Character
	local inScene = character ~= nil and Jloader.GlobalFunctions.PairSceneService.IsInScene(character)

	if inScene then
		current.SeenScene = true
	elseif current.SeenScene or not character then
		stop(nil)
		return
	end

	local profile = current.Profile
	local now = workspace:GetServerTimeNow()

	while current.Pending[1] and current.Pending[1].SpawnAt <= now do
		spawnDot(table.remove(current.Pending, 1))
	end

	for index = #current.Live, 1, -1 do
		local dot = current.Live[index]
		local data = dot.Data

		if dot.Done then
			table.remove(current.Live, index)
			continue
		end

		if now > data.HitUntil then
			dot.Done = true
			dot.Handle.Expire()
			table.remove(current.Live, index)
			continue
		end

		dot.Handle.Update((now - data.SpawnAt) / profile.ShrinkTime, dt)

		if now >= data.HitFrom then
			dot.Handle.Ready()
		end
	end
end

local function onKey(input: InputObject, processed: boolean)
	if processed or not current or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	local name = input.KeyCode.Name
	local chosen = nil

	for _, dot in current.Live do
		if not dot.Done and dot.Data.Key == name and (not chosen or dot.Data.SpawnAt < chosen.Data.SpawnAt) then
			chosen = dot
		end
	end

	if chosen then
		press(chosen)
	end
end

local function start(payload)
	stop(nil)

	local profile = StruggleLibrary.Profiles[payload.Profile]
	local source = template()
	if not profile or not source then return end

	local gui = source:Clone()
	local bubble = gui.Templates.Bubble

	bubble.Visible = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local pending = table.clone(payload.Dots)

	table.sort(pending, function(a, b)
		return a.SpawnAt < b.SpawnAt
	end)

	current = {
		Id = payload.Id,
		Profile = profile,
		Gui = gui,
		Bubble = bubble,
		Board = gui.Board,
		Pending = pending,
		Live = {},
	}
end

function StruggleHandler:Load()
	task.spawn(function()
		while not relay do
			relay = Jloader.GetService("StruggleService")

			if not relay then
				task.wait(1)
			end
		end

		relay.Begin:Connect(start)
		relay.Ended:Connect(function(id)
			stop(id)
		end)
	end)

	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(onKey)
end

return StruggleHandler
