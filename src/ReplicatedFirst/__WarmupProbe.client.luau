local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local remote = ReplicatedStorage:WaitForChild("__WarmupProbe")
local player = Players.LocalPlayer

local function send(text)
	remote:FireServer(text)
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local offsets, worstFrame, worstQueue = {}, 0, 0

remote.OnClientEvent:Connect(function(stamp)
	table.insert(offsets, workspace:GetServerTimeNow() - stamp)
end)

RunService.RenderStepped:Connect(function(dt)
	worstFrame = math.max(worstFrame, dt)
	worstQueue = math.max(worstQueue, ContentProvider.RequestQueueSize)
end)

task.spawn(function()
	while true do
		task.wait(5)

		local count = #offsets

		if count > 0 then
			local lo, hi, sum = math.huge, -math.huge, 0

			for _, value in offsets do
				lo = math.min(lo, value)
				hi = math.max(hi, value)
				sum += value
			end

			send(string.format("clock: stamp age %.0f ms avg (%.0f..%.0f, n%d) | worst frame %.0f ms | asset queue peak %d",
				sum / count * 1000, lo * 1000, hi * 1000, count, worstFrame * 1000, worstQueue))
		end

		table.clear(offsets)
		worstFrame, worstQueue = 0, 0
	end
end)

send("probe client up")

if not player.Character then
	player.CharacterAdded:Wait()
end

local Service = ReplicatedStorage:WaitForChild("JLoader"):WaitForChild("Shared"):WaitForChild("GlobalFunctions"):WaitForChild("Service")
local KnockbackService = require(Service:WaitForChild("KnockbackService"))
local live = workspace:WaitForChild("World"):WaitForChild("Live")
local tracked = {}

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()

	for _, model in live:GetChildren() do
		local recipe = KnockbackService.Active(model)

		if recipe and not tracked[recipe] then
			local body = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")

			if body then
				tracked[recipe] = {
					model = model,
					body = body,
					start = flat(body.Position),
					arrival = now - recipe.startTime,
					err = 0,
					peak = 0,
					input = false,
					who = (model == player.Character and "OWN") or (Players:GetPlayerFromCharacter(model) and "OTHER-PLAYER") or "NPC",
				}
			end
		end
	end

	for recipe, state in tracked do
		local ends = recipe.startTime + recipe.curve.duration

		if not state.cut and now < ends and KnockbackService.Active(state.model) ~= recipe then
			state.cut = true
		end

		if now <= ends then
			if not state.cut and state.body.Parent then
				state.peak = math.max(state.peak, flat(state.body.AssemblyLinearVelocity).Magnitude)

				if not recipe.steer then
					local planned = KnockbackService.Evaluate(recipe, now)
					state.err = math.max(state.err, (flat(state.body.Position) - flat(planned)).Magnitude)
				end

				local humanoid = state.who == "OWN" and state.model:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
					state.input = true
				end
			end
		elseif now > ends + 0.1 then
			tracked[recipe] = nil

			local moved = state.body.Parent and (flat(state.body.Position) - state.start).Magnitude or -1

			send(string.format("%s %s %s: arrived %+.0f ms | peak %.1f studs/s (curve %.1f) | path err %.2f | moved %.2f of %.2f%s%s",
				state.who, state.model.Name, recipe.steer and "lunge" or (recipe.id and "knockback" or "recipe"),
				state.arrival * 1000, state.peak, recipe.curve.speed or 0, state.err, moved, recipe.distance or -1,
				state.input and " [moving]" or "", state.cut and " (cut by next hit)" or ""))
		end
	end
end)
