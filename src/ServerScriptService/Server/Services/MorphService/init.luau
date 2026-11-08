local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Abilities = require("@self/Abilities")
local Profile = require("@self/Profile")
local Strike = require("@self/Strike")
local Swap = require("@self/Swap")
local Types = require("@self/Types")

type Morph = Types.Morph
type Profile = Types.Profile

local MorphService = Jloader.CreateService({
	Name = script.Name,
	Signals = {
		Remote = { "Swing", "Strike", "Hold", "Ability" },
		Basic = { "Morphed", "Unmorphed" },
	},
})

MorphService.Settings = {
	StashName = "MorphStash", --@ ServerStorage folder holding a morphed player's weapons until they turn back
	StrikeTolerance = 8, --@ Studs past reach + radius a reported victim's surface may sit, for lag
	MaxVictims = 8, --@ Most victims one bite report may name
	EarlyStrike = 0.5, --@ Share of the windup that must pass before a reported bite counts
	LateStrike = 1, --@ Seconds after the swing ends that a report still counts
	SwingSlack = 0.8, --@ Share of the last swing's windup + recovery that must pass before the next swing counts
} :: Types.Settings

local GlobalFunctions = Jloader.GlobalFunctions
local MorphLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("MorphLibrary")

local Morphs: { [Player]: Morph } = {}

local function alive(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function release(morph: Morph)
	for _, guard in morph.Guards do
		guard:Disconnect()
	end

	table.clear(morph.Guards)
end

function MorphService:GetNames(): { string }
	local names = {}

	for _, entry in MorphLibrary:GetChildren() do
		if entry:IsA("ModuleScript") then
			table.insert(names, entry.Name)
		end
	end

	table.sort(names)

	return names
end

function MorphService:Resolve(name: string): (Profile?, string?)
	local resolved, result = pcall(Profile.Get, MorphLibrary, Jloader.GetService("MobService"), name)

	if resolved then
		return result, nil
	end

	return nil, (string.gsub(tostring(result), "^.-:%d+: ", ""))
end

function MorphService:Of(player: Player): Morph?
	return Morphs[player]
end

function MorphService:Describe(name: string): string?
	local profile = self:Resolve(name)
	return if profile then Profile.Describe(profile) else nil
end

function MorphService:Morph(player: Player, name: string): (boolean, string?)
	local profile, problem = self:Resolve(name)
	if not profile then return false, problem end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not character or not root or not root:IsA("BasePart") then return false, `{player.Name} has no character to morph` end
	if not alive(character) then return false, `{player.Name} is dead` end

	local settings = self.Settings
	local previous = Morphs[player]

	if previous then
		release(previous)
	else
		Swap.Stash(player, character, settings)
	end

	local model = Swap.Body(profile, root.CFrame, character)
	local morph: Morph = {
		Name = profile.Name,
		Profile = profile,
		Model = model,
		Player = player,
		Swing = nil,
		Ability = nil,
		ReadyAt = {},
		Tools = {},
		Guards = {},
	}

	Morphs[player] = morph

	Swap.Possess(player, character, model, profile)
	morph.Guards = Swap.Guard(player, model, settings)
	Abilities.Grant(morph)

	model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(game) or Morphs[player] ~= morph then return end

		release(morph)
		Morphs[player] = nil
	end)

	if not previous then
		local returned: RBXScriptConnection

		returned = player.CharacterAdded:Connect(function(added: Model)
			if GlobalFunctions.CharacterService.MorphOf(added) then return end

			returned:Disconnect()

			local current = Morphs[player]

			if current then
				release(current)
				Morphs[player] = nil
			end

			Swap.Unstash(player, settings)
			MorphService.Unmorphed:Fire(player, added)
		end)
	end

	MorphService.Morphed:Fire(player, model, profile.Name)

	return true, nil
end

function MorphService:Unmorph(player: Player): (boolean, string?)
	local morph = Morphs[player]
	if not morph then return false, `{player.Name} is not morphed` end

	local root = morph.Model.PrimaryPart
	local frame = if root then root.CFrame else nil

	release(morph)

	player.CharacterAdded:Once(function(character: Model)
		if frame then
			Swap.Place(character, frame)
		end
	end)

	player:LoadCharacter()

	return true, nil
end

function MorphService:Init()
	local settings = self.Settings

	self.Swing:Connect(function(player: Player, index: unknown)
		local morph = Morphs[player]

		if morph then
			Strike.Swing(morph, index, settings)
		end
	end)

	self.Strike:Connect(function(player: Player, index: unknown, victims: unknown, root: unknown)
		local morph = Morphs[player]

		if morph then
			Strike.Land(morph, index, victims, root, settings)
		end
	end)

	self.Ability:Connect(function(player: Player, name: unknown)
		local morph = Morphs[player]

		if morph then
			Abilities.Use(morph, name, settings, function(used: string, result: string)
				self.Ability:Fire(player, used, result)
			end)
		end
	end)

	self.Hold:Connect(function(player: Player, attribute: unknown, on: unknown)
		local morph = Morphs[player]
		if not morph or typeof(attribute) ~= "string" or not morph.Profile.Holds[attribute] then return end

		if morph.Model.Parent then
			morph.Model:SetAttribute(attribute, if on == true then true else nil)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local morph = Morphs[player]

		if morph then
			release(morph)
			Morphs[player] = nil
		end

		Swap.Forget(player, settings)
	end)
end

return MorphService
