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

--@ WeaponsLibrary is a FOLDER of one ModuleScript per weapon, not a single table.
--@ The module NAME is the weapon id and must match the Tool's name exactly.
local WeaponsLibrary = Libraries:WaitForChild("WeaponsLibrary")

local Storage = ReplicatedStorage.Storage
local Other = Storage.Other
local Models = Storage.Models
local Weapons = Models.Weapons
local RigParts = Models.RigParts
local Rigs = Storage.Rigs

--@ Marks every instance RigCharacter adds to a live character, so re-rigging can
--@ strip the previous weapon without touching anything the character shipped with.
local RIG_PART_ATTRIBUTE = "RigPart"

--@ Resolved through descendants rather than direct indexing, so weapons can be grouped
--@ into subfolders (categories, tiers) without this lookup changing.
local function GetWeaponData(WeaponName : string)
	local Module = WeaponsLibrary:FindFirstChild(WeaponName, true)

	if not Module or not Module:IsA("ModuleScript") then return nil end

	local Loaded, Data = pcall(require, Module)

	if not Loaded then
		warn(`[ServerController] Weapon module "{Module:GetFullName()}" failed to load: {Data}`)
		return nil
	end

	return Data
end

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

	self:RigCharacter(Character)

	for Attribute, Value in AttributesLibrary do
		if not Character:GetAttribute(Attribute) then
			Character:SetAttribute(Attribute, Value)
		end
	end
end

--@ Removes every part/joint a previous rig pass welded onto the character.
function CharacterProfile.ClearRig(Character : Model)
	for _, Descendant in Character:GetDescendants() do
		if Descendant:GetAttribute(RIG_PART_ATTRIBUTE) then
			Descendant:Destroy()
		end
	end
end

--@ Resolves the Tool -> WeaponsLibrary entry -> rig template, then transplants the
--@ rig's non-skeleton geometry onto the live character.
--@
--@ A rig template (Storage.Rigs.<Name>) is a full R6 dummy: its skeleton joints
--@ (Neck, Right Shoulder, RootJoint...) already exist on the character and are
--@ skipped. What we want are the joints whose Part1 is a part the character does
--@ NOT have - the weapon geometry. Those get cloned in with the Motor6D NAME
--@ preserved, because the uploaded animations drive the weapon through that joint
--@ name (e.g. "Meshes/diamond stafflow").
function CharacterProfile:ApplyRig(Character : Model, Tool : Tool?)
	CharacterProfile.ClearRig(Character)

	local WeaponName = Tool and Tool.Name

	if not WeaponName then
		Character:SetAttribute("EquippedWeapon", nil)
		return
	end

	local WeaponData = GetWeaponData(WeaponName)

	if not WeaponData then
		warn(`[ServerController] Tool "{WeaponName}" has no module under Libraries.WeaponsLibrary - character left unrigged.`)
		Character:SetAttribute("EquippedWeapon", nil)
		return
	end

	if not WeaponData.Rig then
		--@ A weapon with no Rig is valid (unarmed, or geometry not authored yet). Publish
		--@ the id anyway so the client still resolves that weapon's animation set.
		Character:SetAttribute("EquippedWeapon", WeaponName)
		return
	end

	local Template = Rigs:FindFirstChild(WeaponData.Rig)

	if not Template then
		warn(`[ServerController] Weapon "{WeaponName}" names rig "{tostring(WeaponData.Rig)}", which is missing from Storage.Rigs.`)
		Character:SetAttribute("EquippedWeapon", nil)
		return
	end

	local Applied = 0

	for _, Joint in Template:GetDescendants() do
		if not Joint:IsA("Motor6D") then continue end

		local Limb = Joint.Part0
		local Piece = Joint.Part1

		if not Limb or not Piece then continue end

		local CharacterLimb = Character:FindFirstChild(Limb.Name)

		if not CharacterLimb or not CharacterLimb:IsA("BasePart") then continue end
		if Character:FindFirstChild(Piece.Name) then continue end --@ Skeleton joint, the character already owns it

		local PieceClone = Piece:Clone()
		PieceClone:SetAttribute(RIG_PART_ATTRIBUTE, true)
		PieceClone.CanCollide = false
		PieceClone.CanQuery = false
		PieceClone.CanTouch = false
		PieceClone.Massless = true
		PieceClone.Parent = Character

		local JointClone = Joint:Clone()
		JointClone:SetAttribute(RIG_PART_ATTRIBUTE, true)
		JointClone.Part0 = CharacterLimb
		JointClone.Part1 = PieceClone
		JointClone.Parent = CharacterLimb

		Applied += 1
	end

	if Applied == 0 then
		warn(`[ServerController] Rig "{Template.Name}" welded nothing onto {Character.Name} - no Motor6D in the template attaches a part the character lacks.`)
		Character:SetAttribute("EquippedWeapon", nil)
		return
	end

	--@ Replicated so every client's CombatConfig:ResolveWeaponId agrees on the weapon;
	--@ the client owns idle/attack animation swapping off the back of this.
	Character:SetAttribute("EquippedWeapon", WeaponName)
end

function CharacterProfile:RigCharacter(Character : Model)
	if not Character then return end

	--@ Spawn pass: tools live in the Backpack until equipped, so this is usually a no-op
	--@ that just clears state. The listeners below are what actually drive rigging.
	self:ApplyRig(Character, Character:FindFirstChildOfClass("Tool"))

	if not self._Trove then return end

	self._Trove:Connect(Character.ChildAdded, function(Child)
		if not Child:IsA("Tool") then return end
		self:ApplyRig(Character, Child)
	end)

	self._Trove:Connect(Character.ChildRemoved, function(Child)
		if not Child:IsA("Tool") then return end
		if Character:GetAttribute("EquippedWeapon") ~= Child.Name then return end

		--@ Fall through to whatever else is still equipped, if anything
		self:ApplyRig(Character, Character:FindFirstChildOfClass("Tool"))
	end)
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
