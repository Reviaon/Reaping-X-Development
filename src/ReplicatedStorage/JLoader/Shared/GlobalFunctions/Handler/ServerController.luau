--@ ServerController

--[[
	Server-side counterpart to ClientController.

	Modules are cached on first require(), so every server Service and
	handler that accesses GlobalFunctions.ServerController receives the SAME
	table reference - making it a natural shared store across the server,
	exactly like ClientController is on the client.

	The difference: the client owns ONE LocalPlayer character, so its
	controller is a pure singleton. The server owns MANY characters at once,
	so alongside the shared State store this controller also manages a
	per-character Profile cache - the old ProfileHandler code, preserved
	below verbatim as the CharacterProfile class.

	Usage:
		local ServerController = GlobalFunctions.ServerController

		-- Shared server-wide state (mirrors ClientController)
		ServerController:Set("RoundActive", true)
		local active = ServerController:Get("RoundActive")
		ServerController:Update({ RoundActive = false, Wave = 3 })
		ServerController:Remove("Wave")
		ServerController:Reset()

		-- Per-character profiles (the ProfileHandler role)
		local profile = ServerController:SetCharacter(character)   -- create + cache
		local profile = ServerController:GetProfile(character)     -- retrieve
		ServerController:ClearCharacter(character)                 -- destroy + remove
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local JLoader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = JLoader.GlobalFunctions

local Trove = GlobalFunctions.Trove

local Libraries = ReplicatedStorage:WaitForChild("Libraries")

local AttributesLibrary = require(Libraries.AttributesLibrary)

local Storage = ReplicatedStorage.Storage
local Other = Storage.Other
local Models = Storage.Models
local Weapons = Models.Weapons
local RigParts = Models.RigParts

--========================================================================
--@ CharacterProfile  (preserved ProfileHandler code - per-character state)
--========================================================================

local CharacterProfile = {}

CharacterProfile.__index = CharacterProfile
CharacterProfile.ProfileCache = {}

--@ Default humanoid properties applied to every character on spawn
CharacterProfile.DefaultSettings = {
	WalkSpeed = 10,
	JumpPower = 50,
	JumpHeight = 7.2,
	MaxHealth = 100,
	Health = 100,
	AutoRotate = false,
	UseJumpPower = true,
	HipHeight = 0,
	MaxSlopeAngle = 89,
}

function CharacterProfile.new(Character)
	local Player = Players:GetPlayerFromCharacter(Character)
	local Humanoid = Character:WaitForChild("Humanoid")
	local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

	if Player then
		Character:SetAttribute("Player", Player.UserId)
	else
		Character:SetAttribute("NotPlayer", true)
	end

	CollectionService:AddTag(Character, "Character")

	local self = {
		_Character = Character,
		_Trove = Trove.new(),

		ClientProperties = {
			["CFrame"] = CFrame.new(),
			["Velocity"] = Vector3.zero,
			["CameraCFrame"] = CFrame.new(),
			["ShiftLock"] = false,
		},
	}

	setmetatable(self, CharacterProfile)

	self._Trove:Connect(Humanoid.Died, function()
		self:Destroy()
	end)

	self:LoadCharacterAppearance(Character)
	CharacterProfile.ProfileCache[Character] = self
	Character:SetAttribute("CharacterLoaded", os.clock())
	return self
end

function CharacterProfile:LoadCharacterAppearance(Character)
	if not Character then return end

	local Humanoid = Character:WaitForChild("Humanoid")

	--@ Apply default humanoid settings
	local Settings = CharacterProfile.DefaultSettings
	Humanoid.WalkSpeed  = Settings.WalkSpeed
	Humanoid.JumpPower = Settings.JumpPower
	Humanoid.JumpHeight = Settings.JumpHeight
	Humanoid.MaxHealth = Settings.MaxHealth
	Humanoid.Health = Settings.Health
	Humanoid.AutoRotate = Settings.AutoRotate
	Humanoid.UseJumpPower = Settings.UseJumpPower
	Humanoid.HipHeight = Settings.HipHeight
	Humanoid.MaxSlopeAngle = Settings.MaxSlopeAngle

	GlobalFunctions.AnimatorService:CreateProfile(Character)
	GlobalFunctions.CooldownService:CreateProfile(Character)
	GlobalFunctions.AnimatorService:LoadPackage(Character, Storage.Animations)

	CharacterProfile:RigCharacter(Character)

	for Attribute, Value in AttributesLibrary do
		if not Character:GetAttribute(Attribute) then
			Character:SetAttribute(Attribute, Value)
		end
	end
end

function CharacterProfile:RigCharacter(Character : Model)
	local Handle = RigParts:FindFirstChild("Handle")
	local RightArm = Character:FindFirstChild("Right Arm")

	if Handle then
		self.Handle = Handle:Clone()
		self.Handle.Parent = Character

		local Motor6D = Instance.new("Motor6D")
		Motor6D.Part0 = RightArm
		Motor6D.Part1 = self.Handle
		Motor6D.Part1.Orientation = Vector3.new(0,180,0)
		Motor6D.Name = "Handle"
		Motor6D.Parent = RightArm
	end
end

function CharacterProfile:GetProfile(Character)
	return CharacterProfile.ProfileCache[Character]
end

function CharacterProfile:AddFor(Time, Callback)
	task.delay(Time, function()
		task.spawn(Callback)
		self:Destroy()
	end)
end

function CharacterProfile:Destroy()
	self._Trove:Destroy()

	CharacterProfile.ProfileCache[self._Character] = nil
end

local ServerController = {}
ServerController.__index = ServerController

ServerController.State = {}

ServerController.CharacterProfile = CharacterProfile
ServerController.Profiles = CharacterProfile.ProfileCache

function ServerController:Set(key: string, value: any)
	self.State[key] = value
end

function ServerController:Get(key: string): any
	return self.State[key]
end

function ServerController:Remove(key: string)
	self.State[key] = nil
end

function ServerController:Update(data: {[string]: any})
	for k, v in pairs(data) do
		self.State[k] = v
	end
end

function ServerController:Reset()
	for k in pairs(self.State) do
		self.State[k] = nil
	end
end

function ServerController:SetCharacter(character: Model)
	return CharacterProfile.new(character)
end

function ServerController:GetProfile(character: Model)
	return CharacterProfile.ProfileCache[character]
end

function ServerController:ClearCharacter(character: Model)
	local profile = CharacterProfile.ProfileCache[character]
	if profile then
		profile:Destroy()
	end
end

return setmetatable(ServerController, {
	__index = function(_, key)
		return ServerController.State[key]
	end,
	__newindex = function(_, key, value)
		ServerController.State[key] = value
	end,
})
