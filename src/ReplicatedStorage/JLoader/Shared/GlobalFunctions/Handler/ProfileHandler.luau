local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local JLoader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = JLoader.GlobalFunctions

local Trove = GlobalFunctions.Trove
local PhysicsService = GlobalFunctions.PhysicsService

local Libraries = ReplicatedStorage:WaitForChild("Libraries")

local AttributesLibrary = require(Libraries.AttributesLibrary)

local Storage = ReplicatedStorage.Storage
local Other = Storage.Other
local Models = Storage.Models
local Weapons = Models.Weapons
local RigParts = Models.RigParts

local CharacterProfile = {}

CharacterProfile.__index = CharacterProfile
CharacterProfile.ProfileCache = {}

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
		_WeaponOriginPoint = nil,

		ApplyPhysicsDragToPos = function(Victim, Config)
			ProfileFunctions.DragToPosition(Victim, Config)
		end,
		
		AddKnockback = function(Attacker, Victim, Settings)
			ProfileFunctions.AddKnockback(Attacker, Victim,Settings)
		end,
		
		ApplyPhysics = function(Character, Config)
			ProfileFunctions.ApplyPhysics(Character, Config)
		end,
		
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
	
	GlobalFunctions.AnimatorService:CreateProfile(Character)
	GlobalFunctions.CooldownService:CreateProfile(Character)
	GlobalFunctions.AnimatorService:LoadPackage(Character, Storage.Animations)
	
	CharacterProfile:RigCharacter(Character)

	Character.ChildAdded:Connect(function(child)
		if not child:GetAttribute("knockback_attribute") then return end
		PhysicsService.ProcessPhysics(Character, child)
	end)

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

return CharacterProfile