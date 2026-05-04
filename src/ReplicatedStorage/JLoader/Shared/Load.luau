local Load = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--@ Check if a method exists on a given table
Load.MethodExists = function(t, m)
	return rawget(t, m) ~= nil
end

--@ Add runners from a list of module scripts or folders
Load.AddRunners = function(List, Raws, Init)
	for _, Set in ipairs(List) do
		if Set:IsA("ModuleScript") then
			table.insert(Raws, Set)
		elseif Set:IsA("Folder") then
			for _, module in ipairs(Set:GetChildren()) do
				if not module:IsA("ModuleScript") then continue end
				table.insert(Raws, module)
			end
		end
	end

	--@ Initialize each module in the raw list
	for _, module in ipairs(Raws) do
		Init(module)
	end
end

Load.LoadRunners = function(List, controllerFactory)
	local Clock = os.clock()

	local Sorted = {}
	for Name, Runner in pairs(List) do
		table.insert(Sorted, Runner)
	end
	table.sort(Sorted, function(a, b)
		return a.Priority > b.Priority
	end)

	local EventInits = {Players = {}, Characters = {}}
	for _, Runner in ipairs(Sorted) do
		if Load.MethodExists(Runner, "Load") then
			task.spawn(Runner.Load, Runner)
		end
		if Load.MethodExists(Runner, "InitPlayer") then
			table.insert(EventInits.Players, Runner)
		end
		if Load.MethodExists(Runner, "InitCharacter") then
			table.insert(EventInits.Characters, Runner)
		end
	end

	local function InitCharacter(Character)
		if not Character then return end
		
		local controller = controllerFactory and controllerFactory(Character) or Character

		for _, Runner in ipairs(EventInits.Characters) do
			local IsLocal = Players.LocalPlayer and Character == Players.LocalPlayer.Character
			task.spawn(Runner.InitCharacter, Runner, controller, IsLocal)
		end
	end

	local Inits = {}
	local function InitPlayer(Player)
		if Inits[Player] then return end
		Inits[Player] = true

		local IsLocal = Players.LocalPlayer
		for _, Runner in ipairs(EventInits.Players) do
			task.spawn(Runner.InitPlayer, Runner, Player, IsLocal)
		end
		task.spawn(InitCharacter, Player.Character)
		Player.CharacterAdded:Connect(InitCharacter)
	end

	--@ Initialize existing players
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(InitPlayer, Player)
	end

	--@ Connect player added and removing events
	Players.PlayerAdded:Connect(InitPlayer)
	Players.PlayerRemoving:Connect(function(Player)
		Inits[Player] = nil
	end)

	print(`[Jloader]: Loaded {RunService:IsServer() and "Server" or "Client"}`)
end

return Load