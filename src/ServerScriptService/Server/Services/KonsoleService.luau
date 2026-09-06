local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local KonsoleService = Jloader.CreateService({ Name = script.Name })

local Players = game:GetService("Players")

local Konsole = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("Konsole"))

local Libraries = ReplicatedStorage:WaitForChild("Libraries")

local WeaponsLibrary = Libraries:WaitForChild("WeaponsLibrary")

local Storage = ReplicatedStorage:WaitForChild("Storage")
local RigParts = Storage:WaitForChild("Models"):WaitForChild("RigParts")

local ServerStorage = game:GetService("ServerStorage")
local NPCs = ServerStorage:WaitForChild("NPCs")

KonsoleService.Settings = {
	--@ Rank a command must clear. 100 matches the built-in kick/ban ceiling.
	CommandRank = 100,

	--@ Name = userId. Both must match; a rename locks that entry out until updated.
	Whitelist = {
		Sizzorsx = 384350386,
		PumpYaK = 356936987,
		Alphirex = 45866635,
		bytemelo = 4964146133,
		bigbossray2 = 807568274
	},

	--@ Re-giving a held weapon replaces it; a weapon is an identity, not a stack.
	ReplaceExisting = true,

	--@ Studs in front of the caller a spawned NPC lands.
	SpawnDistance = 8,

	--@ Most NPCs one command may spawn at once.
	MaxSpawnCount = 25,
}

local function weaponNames()
	local names = {}

	for _, module in WeaponsLibrary:GetDescendants() do
		if module:IsA("ModuleScript") then
			table.insert(names, module.Name)
		end
	end

	table.sort(names)
	return names
end

local function resolve(query, names)
	if type(query) ~= "string" or query == "" then
		return nil, "nothing named"
	end

	for _, name in ipairs(names) do
		if name == query then
			return name
		end
	end

	local wanted = string.lower(query)
	local matches = {}

	for _, name in ipairs(names) do
		local lowered = string.lower(name)

		if lowered == wanted then
			return name
		end

		if string.sub(lowered, 1, #wanted) == wanted then
			table.insert(matches, name)
		end
	end

	if #matches == 1 then
		return matches[1]
	end

	if #matches > 1 then
		return nil, ("'%s' could be %s"):format(query, table.concat(matches, ", "))
	end

	return nil, ("'%s' is not one of: %s"):format(query, table.concat(names, ", "))
end

local function tokenise(text)
	local tokens = {}
	local index = 1

	while index <= #text do
		local character = string.sub(text, index, index)

		if character == " " then
			index += 1

		elseif character == '"' then
			local closing = string.find(text, '"', index + 1, true)

			if closing then
				table.insert(tokens, string.sub(text, index + 1, closing - 1))
				index = closing + 1
			else
				table.insert(tokens, string.sub(text, index + 1))
				break
			end
		else
			local space = string.find(text, " ", index, true) or (#text + 1)
			table.insert(tokens, string.sub(text, index, space - 1))
			index = space
		end
	end

	return tokens
end

local function argumentsOf(context)
	local tokens = tokenise(type(context.text) == "string" and context.text or "")
	table.remove(tokens, 1)
	return tokens
end

local function playerNamed(token)
	if type(token) ~= "string" or token == "" then
		return nil
	end

	local wanted = string.lower(token)

	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == wanted or string.lower(player.DisplayName) == wanted then
			return player
		end
	end

	return nil
end

local function targetOf(context, tokens)
	local last = tokens[#tokens]

	if type(last) == "string" and string.lower(last) == "me" then
		local rest = table.clone(tokens)
		table.remove(rest)
		return context.entity, rest
	end

	if #tokens > 1 then
		local named = playerNamed(last)

		if named then
			local rest = table.clone(tokens)
			table.remove(rest)
			return named, rest
		end
	end

	return context.entity, tokens
end

local allowed = {}

local warned = {}

local function playerOf(entity)
	if typeof(entity) == "Instance" and entity:IsA("Player") then
		return entity
	end

	local id = tonumber(entity)
	return id and Players:GetPlayerByUserId(id) or nil
end

function KonsoleService.Allows(entity)
	local player = playerOf(entity)
	if not player then
		return false
	end

	local expected = allowed[string.lower(player.Name)]
	if not expected then
		return false
	end

	if player.UserId ~= expected then
		if not warned[player.UserId] then
			warned[player.UserId] = true
			warn(("KonsoleService: '%s' is whitelisted as %d and this one is %d, so no commands. Either "
				.. "they renamed and the list needs updating, or this is somebody else wearing the name.")
				:format(player.Name, expected, player.UserId))
		end

		return false
	end

	return true
end

local function buildWeaponTool(weaponName)
	local handle = RigParts:FindFirstChild("Handle")

	if not handle or not handle:IsA("BasePart") then
		return nil, "Storage.Models.RigParts.Handle is missing, so no Tool can be equipped"
	end

	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.RequiresHandle = true

	tool.CanBeDropped = false

	local clone = handle:Clone()
	clone.Name = "Handle"

	clone.Transparency = 1
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Massless = true
	clone.Parent = tool

	return tool
end

local Implementations = {}

function Implementations.giveWeaponServer(context)
	local settings = KonsoleService.Settings
	local tokens = argumentsOf(context)
	local target, rest = targetOf(context, tokens)

	if not target then
		return context.err("no-target", "nobody to give it to")
	end

	local weapon, why = resolve(table.concat(rest, " "), weaponNames())

	if not weapon then
		return context.err("unknown-weapon", why)
	end

	local backpack = target:FindFirstChildOfClass("Backpack")

	if not backpack then
		return context.err("no-backpack", ("%s has no backpack yet"):format(target.Name))
	end

	if settings.ReplaceExisting then
		for _, place in { backpack, target.Character } do
			local existing = place and place:FindFirstChild(weapon)

			if existing and existing:IsA("Tool") then
				existing:Destroy()
			end
		end
	end

	local tool, problem = buildWeaponTool(weapon)

	if not tool then
		return context.err("no-handle", problem)
	end

	tool.Parent = backpack

	if target == context.entity then
		return context.reply(("%s is in your backpack"):format(weapon))
	end

	return context.reply(("gave %s to %s"):format(weapon, target.Name))
end

function Implementations.clearWeaponsServer(context)
	local tokens = argumentsOf(context)
	local target = targetOf(context, tokens)

	if not target then
		return context.err("no-target", "nobody to take them from")
	end

	local removed = 0

	for _, place in { target:FindFirstChildOfClass("Backpack"), target.Character } do
		if place then
			for _, child in place:GetChildren() do
				if child:IsA("Tool") then
					child:Destroy()
					removed += 1
				end
			end
		end
	end

	if removed == 0 then
		return context.reply(("%s had nothing to take"):format(
			target == context.entity and "you" or target.Name))
	end

	return context.reply(("took %d %s off %s"):format(
		removed,
		removed == 1 and "weapon" or "weapons",
		target == context.entity and "you" or target.Name))
end

local SPAWNED_ATTRIBUTE = "KonsoleSpawned"

local function npcNames()
	local names = {}

	for _, model in NPCs:GetChildren() do
		if model:IsA("Model") then
			table.insert(names, model.Name)
		end
	end

	table.sort(names)
	return names
end

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

function Implementations.spawnNpcServer(context)
	local settings = KonsoleService.Settings
	local caller = context.entity

	local character = caller and caller.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return context.err("no-character", "you need a character to spawn in front of")
	end

	local living = livingFolder()
	if not living then
		return context.err("no-live-folder", "workspace.World.Live is missing")
	end

	local tokens = argumentsOf(context)

	local count = 1
	local last = tokens[#tokens]
	if #tokens > 1 and tonumber(last) then
		count = math.clamp(math.floor(tonumber(last)), 1, settings.MaxSpawnCount)
		table.remove(tokens)
	end

	local roster = npcNames()
	if #roster == 0 then
		return context.err("no-npcs", "ServerStorage.NPCs holds no models")
	end

	local wanted = #tokens > 0 and table.concat(tokens, " ") or roster[1]
	local name, why = resolve(wanted, roster)

	if not name then
		return context.err("unknown-npc", why)
	end

	local template = NPCs:FindFirstChild(name)

	for index = 1, count do
		local clone = template:Clone()

		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end

		local sideways = (index - 1) * 4 - ((count - 1) * 4) / 2
		clone:PivotTo(root.CFrame * CFrame.new(sideways, 0, -settings.SpawnDistance))

		clone:SetAttribute(SPAWNED_ATTRIBUTE, true)
		clone.Parent = living
	end

	return context.reply(("spawned %d %s %d studs ahead"):format(count, name, settings.SpawnDistance))
end

function Implementations.debugServer(context)
	local tokens = argumentsOf(context)
	local word = tokens[1] and string.lower(tokens[1]) or nil

	local DebugService = Jloader.GlobalFunctions.DebugService
	local enabled

	if word == nil or word == "toggle" then
		enabled = not DebugService.IsEnabled()
	elseif word == "on" or word == "true" or word == "1" or word == "enable" then
		enabled = true
	elseif word == "off" or word == "false" or word == "0" or word == "disable" then
		enabled = false
	else
		return context.err("bad-argument", ("'%s' is not on, off or toggle"):format(tokens[1]))
	end

	DebugService.Set(enabled)

	return context.reply(("debug mode %s"):format(enabled and "on" or "off"))
end

function Implementations.clearNpcsServer(context)
	local living = livingFolder()
	if not living then
		return context.err("no-live-folder", "workspace.World.Live is missing")
	end

	local removed = 0

	for _, child in living:GetChildren() do
		if child:GetAttribute(SPAWNED_ATTRIBUTE) then
			child:Destroy()
			removed += 1
		end
	end

	if removed == 0 then
		return context.reply("nothing spawned by the console to clear")
	end

	return context.reply(("cleared %d spawned %s"):format(removed, removed == 1 and "npc" or "npcs"))
end

function KonsoleService:Init()
	local settings = self.Settings

	for name, userId in pairs(settings.Whitelist) do
		if type(name) == "string" and type(userId) == "number" then
			allowed[string.lower(name)] = userId
		else
			warn(("KonsoleService: the whitelist wants name = userId, and has %s = %s"):format(
				tostring(name), tostring(userId)))
		end
	end

	Konsole.bindRanks(function(entity)
		return KonsoleService.Allows(entity) and settings.CommandRank or 0
	end)

	Konsole.define({
		name = "give",
		rank = settings.CommandRank,
		aliases = { "giveweapon", "weapon", "tool" },
		description = "Puts a weapon in somebody's backpack.",
		server = "giveWeaponServer",
		args = {
			{
				name = "weapon",
				type = "string",
				required = true,
				suggestions = weaponNames(),
			},
			{
				name = "target",
				type = "string",
				required = false,
			},
		},
	})

	Konsole.define({
		name = "clearweapons",
		rank = settings.CommandRank,
		aliases = { "clearweapon", "unarm", "disarm" },
		description = "Takes every weapon off somebody, held or stowed.",
		server = "clearWeaponsServer",
		args = {
			{
				name = "target",
				type = "string",
				required = false,
			},
		},
	})

	Konsole.define({
		name = "spawn",
		rank = settings.CommandRank,
		aliases = { "spawnnpc", "npc", "dummy" },
		description = "Spawns an NPC from ServerStorage.NPCs in front of you.",
		server = "spawnNpcServer",
		args = {
			{
				name = "npc",
				type = "string",
				required = false,
				suggestions = npcNames(),
			},
			{
				name = "count",
				type = "string",
				required = false,
			},
		},
	})

	Konsole.define({
		name = "debug",
		rank = settings.CommandRank,
		aliases = { "debugmode", "dbg" },
		description = "Toggles debug mode: hitbox volumes, hit reports and status UI.",
		server = "debugServer",
		args = {
			{
				name = "state",
				type = "string",
				required = false,
				suggestions = { "on", "off", "toggle" },
			},
		},
	})

	Konsole.define({
		name = "clearnpcs",
		rank = settings.CommandRank,
		aliases = { "clearnpc", "cleardummies", "despawn" },
		description = "Removes every NPC the console spawned.",
		server = "clearNpcsServer",
	})

	Konsole.host(Implementations)
end

return KonsoleService
