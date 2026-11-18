--[[@
	**ClothingService**: dresses players in 3D layered clothing sets
	- **Sets:** every Model in `ServerStorage.Clothing`, found by name and numbered in natural order (`Set1`, `Set2`, …)
	- **Choice:** saved in the player's data (`Saved`), re-applied on every respawn and after a morph turns back
	  - `Config.Default` until they choose; a spawn waits for their data before dressing
	  - Morph bodies are never dressed
	- **Avatar:** every player body has its own Roblox accessories and clothing stripped, with or without a set (`Avatar`)
	- **Konsole:** `outfit <number|name|off> [player]`
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Avatar = require("@self/Avatar")
local Config = require("@self/Config")
local Dress = require("@self/Dress")
local Fit = require("@self/Fit")
local Saved = require("@self/Saved")

local ClothingService = Jloader.CreateService({ Name = script.Name })

local GlobalFunctions = Jloader.GlobalFunctions

local function folder(): Instance?
	return ServerStorage:FindFirstChild(Config.Folder)
end

local function sortKey(name: string): (string, number)
	local stem, number = string.match(name, "^(.-)(%d+)$")

	if stem and number then
		return string.lower(stem), tonumber(number) :: number
	end

	return string.lower(name), -1
end

local function apply(character: Model, name: string?)
	if GlobalFunctions.CharacterService.MorphOf(character) then return end

	if not name then
		Dress.Strip(character)
		return
	end

	local source = folder()
	local model = source and source:FindFirstChild(name)

	if not model or not model:IsA("Model") then
		warn(`[ClothingService] No set "{name}" under ServerStorage.{Config.Folder}`)
		Dress.Strip(character)
		return
	end

	local set, problem = Fit.Get(model)

	if not set then
		warn(`[ClothingService] {problem}`)
		Dress.Strip(character)
		return
	end

	Dress.Wear(character, set)
end

function ClothingService:GetNames(): { string }
	local names = {}
	local source = folder()

	if not source then return names end

	for _, child in source:GetChildren() do
		if child:IsA("Model") then
			table.insert(names, child.Name)
		end
	end

	table.sort(names, function(a: string, b: string): boolean
		local stemA, numberA = sortKey(a)
		local stemB, numberB = sortKey(b)

		if stemA ~= stemB then return stemA < stemB end

		return numberA < numberB
	end)

	return names
end

function ClothingService:Current(player: Player): string?
	return Saved.Get(player)
end

function ClothingService:Wear(player: Player, name: string?)
	Saved.Set(player, name)

	local character = player.Character

	if character then
		apply(character, name)
	end
end

function ClothingService:Dress(player: Player, query: string): (string?, string?)
	local wanted = string.lower(query)

	if Config.OffWords[wanted] then
		self:Wear(player, nil)
		return "none", nil
	end

	local names = self:GetNames()

	if #names == 0 then
		return nil, `ServerStorage.{Config.Folder} holds no sets`
	end

	local index = tonumber(query)
	local name: string? = nil

	if index then
		name = names[index]
	else
		for _, candidate in names do
			if string.lower(candidate) == wanted then
				name = candidate
				break
			end
		end
	end

	if not name then
		return nil, `no set "{query}"; try {table.concat(names, ", ")} or 1-{#names}`
	end

	self:Wear(player, name)

	return name, nil
end

function ClothingService:Init()
	local function track(player: Player)
		local function dress(character: Model)
			task.spawn(function()
				if not character:WaitForChild("Torso", 10) then return end
				if GlobalFunctions.CharacterService.MorphOf(character) then return end

				if Config.StripAvatar then
					Avatar.Guard(character)
				end

				Saved.Wait(player)

				local name = Saved.Get(player)

				if name and character.Parent then
					apply(character, name)
				end
			end)
		end

		player.CharacterAdded:Connect(dress)

		if player.Character then
			dress(player.Character)
		end
	end

	Players.PlayerAdded:Connect(track)

	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return ClothingService
