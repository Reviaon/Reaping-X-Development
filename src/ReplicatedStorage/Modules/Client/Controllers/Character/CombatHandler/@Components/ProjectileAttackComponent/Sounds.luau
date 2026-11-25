local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("./Config")
local Weapon = require("./Weapon")

local Sounds = {}

local held = setmetatable({} :: { [Model]: { [string]: Sound } }, { __mode = "k" })

local function play(path: unknown, options: { [string]: any }): Sound?
	if typeof(path) ~= "string" then return nil end
	return Jloader.GlobalFunctions.SoundService:TryPlay(path, options)
end

local function stop(character: Model, key: string)
	local sounds = held[character]
	local sound = sounds and sounds[key]
	if not sound then return end

	sounds[key] = nil
	Jloader.GlobalFunctions.SoundService:Stop(sound, Config.SoundCancelFade)
end

function Sounds.Cancel(character: Model?)
	if not character then return end

	stop(character, "draw")
	stop(character, "reload")
end

function Sounds.Phase(character: Model?, projectile, phase: string, previous: string?)
	if not character then return end

	if phase ~= "Drawing" and phase ~= "Holding" then
		stop(character, "draw")
	end

	local sounds = projectile and projectile.sounds
	local root = character:FindFirstChild("HumanoidRootPart")
	if typeof(sounds) ~= "table" or not root then return end

	local path = if phase == "Drawing" then sounds.draw
		elseif phase == "Reloading" then sounds.reload
		elseif phase == "Firing" then (if previous == "Holding" then sounds.charged else sounds.quick)
		else nil

	local key = Config.ClipKey[phase]
	local speed = if key then Weapon.TierSpeed(character, projectile, key) else 1
	local sound = play(path, { Parent = root, PlaybackSpeed = speed })

	if sound and (key == "draw" or key == "reload") then
		stop(character, key)

		local kept = held[character] or {}
		held[character] = kept
		kept[key] = sound
	end
end

function Sounds.Impact(projectile, result: RaycastResult)
	local sounds = projectile and projectile.sounds
	local impact = typeof(sounds) == "table" and sounds.impact
	if typeof(impact) ~= "table" or typeof(impact.path) ~= "string" then return end

	local materials = if typeof(impact.materials) == "table" then impact.materials else {}
	local kind = materials[result.Material] or impact.fallback
	if typeof(kind) ~= "string" then return end

	play(`{impact.path}.{kind}`, { Position = result.Position })
end

return Sounds
