local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Settings = {
	Swing = "Weapons.%s.Whiff", --@ Played on every swing, by WeaponsLibrary id
	Hit = "Weapons.%s.Hit", --@ Played on a landed hit, by WeaponsLibrary id
	MobHit = "Mobs.%s.Hit", --@ Played on a mob's landed hit, by its MobLibrary name
	HitOverrides = { --@ Hit ids that aren't weapons -> the path they play
		Push = "Abilities.Push.Hit",
	},
	MobLibrary = { "Libraries", "MobLibrary" }, --@ Under ReplicatedStorage; an attacker named like an entry here is a mob
}

local CombatSounds = {}

local function rootOf(model: Instance?): BasePart?
	local root = model and (model:FindFirstChild("HumanoidRootPart") or (model:IsA("Model") and model.PrimaryPart))
	return if root and root:IsA("BasePart") then root else nil
end

local function isMob(model: Instance?): boolean
	if not model or not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then
		return false
	end

	local library: Instance? = ReplicatedStorage
	for _, segment in Settings.MobLibrary do
		library = library and library:FindFirstChild(segment)
	end

	return library ~= nil and library:FindFirstChild(model.Name) ~= nil
end

local function sounds()
	return Jloader.GlobalFunctions.SoundService
end

local function numberOf(comboIndex: unknown): number?
	return if typeof(comboIndex) == "number" and comboIndex >= 1 then comboIndex else nil
end

function CombatSounds.Swing(character: Model?, weaponId: string?, comboIndex: number?): Sound?
	local root = rootOf(character)
	if not root or typeof(weaponId) ~= "string" then return nil end

	return sounds():TryPlay(string.format(Settings.Swing, weaponId), { Parent = root, Number = numberOf(comboIndex) })
end

function CombatSounds.HitPath(attacker: Instance?, weaponId: string?): string?
	if isMob(attacker) then
		return string.format(Settings.MobHit, (attacker :: Model).Name)
	end

	if typeof(weaponId) ~= "string" then return nil end

	return Settings.HitOverrides[weaponId] or string.format(Settings.Hit, weaponId)
end

function CombatSounds.Hit(victim: Model, attacker: Instance?, weaponId: string?, point: Vector3?, comboIndex: number?): Sound?
	local path = CombatSounds.HitPath(attacker, weaponId)
	if not path then return nil end

	local number = numberOf(comboIndex)

	if typeof(point) == "Vector3" then
		return sounds():TryPlay(path, { Position = point, Number = number })
	end

	local root = rootOf(victim)
	return if root then sounds():TryPlay(path, { Parent = root, Number = number }) else nil
end

CombatSounds.Settings = Settings

return CombatSounds
