local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local Mob = require("@self/Core/Mob")
local Rig = require("@self/Body/Rig")
local Scheduler = require("@self/Core/Scheduler")
local Team = require("@self/Team")
local Telemetry = require("@self/Core/Telemetry")
local Spacing = require("@self/Body/Spacing")
local Config = require("@self/Config")
local Tree = require("@self/Brain/Tree")
local Dodge = require("@self/Combat/Dodge")
local Awareness = require("@self/Senses/Awareness")
local Inspect = require("@self/Inspect")

local MobService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Basic = { "Spawned", "Removed" } },
})

MobService.Settings = {
	TemplateFolder = "Mobs", --@ ServerStorage folder holding each mob's template model
	MobAttribute = "Mob", --@ Set on every mob model to its MobLibrary name
	MaxThinksPerFrame = 30, --@ Brain ticks allowed per Heartbeat across all mobs
	TelemetryInterval = 1, --@ Seconds between the cost readouts published as attributes on this service's folder
	Tiers = { --@ Nearest-player distance -> seconds between brain ticks, whether it animates, and whether it moves every frame
		{ range = 90, interval = 0.1, animate = true },
		{ range = 220, interval = 0.4, animate = true },
		{ range = math.huge, interval = 1.5, animate = false, smooth = false },
	},
}

local MobLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("MobLibrary")

local Kinds = {}
local Mobs = {}
local ByModel = {}
local Connection = nil
local Stats = nil
local Crowd = Spacing.Grid()

local function liveFolder(): Instance
	return workspace:WaitForChild("World"):WaitForChild("Live")
end

function MobService:GetKind(name: string)
	local kind = Kinds[name]
	if kind then return kind end

	local entry = MobLibrary:FindFirstChild(name)

	if not entry or not entry:IsA("ModuleScript") then
		error(`[MobService] "{tostring(name)}" has no entry under Libraries.MobLibrary.`, 2)
	end

	local config = Config.Resolve(Config.Gather(entry))
	local templates = ServerStorage:FindFirstChild(self.Settings.TemplateFolder)
	local templateName = config.template or name
	local template = templates and templates:FindFirstChild(templateName)

	if not template or not template:IsA("Model") then
		error(`[MobService] {name} needs a template model at ServerStorage.{self.Settings.TemplateFolder}.{templateName}.`, 2)
	end

	local prototype = Rig.Prepare(template, config)

	Config.Derive(config, Rig.Body(prototype))

	kind = {
		Name = name,
		Config = config,
		Template = template,
		Prototype = prototype,
		Tree = Tree.Get(script.Brain.Trees, config.tree),
	}

	Kinds[name] = kind

	return kind
end

function MobService:ResolveKind(name: string)
	local resolved, result = pcall(self.GetKind, self, name)

	if resolved then
		return result
	end

	return nil, (string.gsub(tostring(result), "^.-:%d+: ", ""))
end

function MobService:GetNames(): { string }
	local names = {}

	for _, entry in MobLibrary:GetChildren() do
		if entry:IsA("ModuleScript") then
			table.insert(names, entry.Name)
		end
	end

	table.sort(names)

	return names
end

function MobService:Spawn(name: string, ground: Vector3, options)
	options = options or {}

	local started = os.clock()

	local kind = self:GetKind(name)
	local config = kind.Config
	local model = Rig.Spawn(kind.Prototype, ground, options.Yaw)

	model.Name = name
	model:SetAttribute(self.Settings.MobAttribute, name)
	model:SetAttribute(GlobalFunctions.ServerController.CharacterProfile.NoPackageAttribute, true)
	model.Parent = liveFolder()

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	GlobalFunctions.ServerController:SetCharacter(model)
	Rig.Activate(model, humanoid)

	humanoid.MaxHealth = config.health
	humanoid.Health = config.health

	local mob = Mob.new(kind, model, options.Home or ground)

	Team.Join(mob, options.Team)

	mob.Crowd = Crowd
	Mobs[mob] = true
	ByModel[model] = mob

	mob.Destroying:Connect(function()
		Mobs[mob] = nil
		ByModel[model] = nil
		MobService.Removed:Fire(mob)
	end)

	MobService.Spawned:Fire(mob)

	if Stats then
		Stats:Spawned(os.clock() - started)
	end

	return mob
end

function MobService:Despawn(mob)
	mob:Destroy()
end

function MobService:GetMob(model: Model)
	return ByModel[model]
end

function MobService:GetMobs()
	return Mobs
end

function MobService:Count(name: string?): number
	local count = 0

	for mob in Mobs do
		if not name or mob.Name == name then
			count += 1
		end
	end

	return count
end

function MobService:Inspect(origin: Vector3, words: { string }): (string?, string?)
	return Inspect.Run(Mobs, origin, words, { Folder = self.Folder })
end

function MobService:InspectWords(): { string }
	return Inspect.Words()
end

function MobService:Clear()
	for mob in Mobs do
		mob:Destroy()
	end
end

function MobService:Load()
	if Connection then
		Connection:Disconnect()
	end

	Jloader.GetService("CombatService").Provoked:Connect(function(attacker, victim, damage)
		local mob = ByModel[victim]

		if mob then
			mob:Provoke(attacker, damage)

			if mob.Team then
				mob.Team:NoteAssault(mob, attacker)
			end
		end
	end)

	local CombatService = Jloader.GetService("CombatService")

	CombatService.Swung:Connect(function(attacker)
		Dodge.React(Mobs, attacker, CombatService)
	end)

	Jloader.GetService("RangedService").Fired:Connect(function(archer, origin, direction)
		Awareness.Release.React(Mobs, archer, origin, direction)
	end)

	Stats = Telemetry.new(self.Folder, self.Settings.TelemetryInterval)

	Connection = RunService.Heartbeat:Connect(function(dt)
		local started = os.clock()

		Crowd:Rebuild(Mobs)

		local thinks, count = Scheduler.Step(Mobs, started, dt, self.Settings)

		Stats:Frame(os.clock() - started, thinks, count)
	end)
end

return MobService
