--@ Start
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local Main = Jloader.CreateService{Name = script.Name}

--@ Services
local ServerStorage = game:GetService('ServerStorage')
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

--@ Assets
local Storage = ReplicatedStorage.Storage
local Live = workspace:WaitForChild("World"):WaitForChild("Live")
local DataService = require(script.Parent.DataService)

--@ Import
local GlobalFunctions = Jloader.GlobalFunctions;

--@ CharacterHandler Class
local CharacterHandler = {}
CharacterHandler.__index = CharacterHandler

function CharacterHandler.new(player)
	local self = setmetatable({}, CharacterHandler)
	
	self.Player = player
	self.Character = player.Character or player.CharacterAdded:Wait()
	
	self.EffectService = Jloader.GetService("EffectService")
	self.Trove = GlobalFunctions.Trove.new()

	if self.Character then
		self:InitializeCharacter()
	end

	self.Trove:Add(self.Character:WaitForChild("Humanoid").Died:Connect(function()
		self:OnCharacterDied()
	end))

	self.Trove:Add(self.Character.AncestryChanged:Connect(function()
		self:OnCharacterRemoved()
	end))

	return self
end

function CharacterHandler:InitializeCharacter()
	task.spawn(function()
		RunService.Stepped:Wait()

		GlobalFunctions.ServerController:SetCharacter(self.Character)

		self.EffectService.CreateVisual:FireAll({
			Set = "SpawnVisuals",
			Effect = "ForceField",
			Info = {
				Char = self.Character,
				LifeTime = 5
			}
		})

		self.Character.Parent = Live
		self.Character.PrimaryPart = self.Character:WaitForChild("HumanoidRootPart")
	end)
end

function CharacterHandler:OnCharacterDied()
	GlobalFunctions.AnimatorService:RemoveProfile(self.Character)
	GlobalFunctions.CooldownService:RemoveProfile(self.Character)
	self.Trove:Clean()
end

function CharacterHandler:OnCharacterRemoved()
	GlobalFunctions.AnimatorService:RemoveProfile(self.Character)
	GlobalFunctions.CooldownService:RemoveProfile(self.Character)
	self.Trove:Clean()
end

local GameService = {}
GameService.__index = GameService

function GameService.new()
	local self = setmetatable({}, GameService)
	self.CharacterHandlers = {}

	self:Initialize()
	return self
end

function GameService:Initialize()
	Players.PlayerAdded:Connect(function(player)
		DataService.InitPlr(player, "Player")
		self.CharacterHandlers[player] = CharacterHandler.new(player)

		player.CharacterAdded:Connect(function()
			if self.CharacterHandlers[player] then
				self.CharacterHandlers[player].Trove:Clean()
			end
			self.CharacterHandlers[player] = CharacterHandler.new(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.RemovePlr(player, "Player")
		if self.CharacterHandlers[player] then
			self.CharacterHandlers[player].Trove:Destroy()
			self.CharacterHandlers[player] = nil
		end
	end)

	for _, live in Live:GetChildren() do
		if live:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(live) then
			GlobalFunctions.ServerController:SetCharacter(live)
		end
	end

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.RemovePlr(player, "Player")
		end
	end)
end

function Main:Init()
	self.GameService = GameService.new()
end

return Main
