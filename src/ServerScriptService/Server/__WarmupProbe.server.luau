local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "__WarmupProbe"
remote.Parent = ReplicatedStorage

local log = Instance.new("StringValue")
log.Name = "__WarmupLog"
log.Parent = ServerStorage

local lines = {}

local function add(text)
	table.insert(lines, string.format("[%6.1fs] %s", workspace.DistributedGameTime, text))

	if #lines > 500 then
		table.remove(lines, 1)
	end

	log.Value = table.concat(lines, "\n")
end

remote.OnServerEvent:Connect(function(player, text)
	if typeof(text) == "string" then
		add(player.Name .. ": " .. text)
	end
end)

Players.PlayerAdded:Connect(function(player)
	add("joined " .. player.Name)
end)

task.spawn(function()
	while true do
		remote:FireAllClients(workspace:GetServerTimeNow())
		task.wait(0.25)
	end
end)

add("probe server up")
