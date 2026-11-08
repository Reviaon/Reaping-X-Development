local Jloader = require("@game/ReplicatedStorage/JLoader")

local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")
local Attacks = require("../MobService/Combat/Attacks")
local Profile = require("./Profile")
local Strike = require("./Strike")
local Types = require("./Types")

type Morph = Types.Morph
type Settings = Types.Settings
type Spec = Types.Spec
type Result = MorphTypes.AbilityResult

local Abilities = {}

local GlobalFunctions = Jloader.GlobalFunctions

local ATTACKING = "IsAttacking"
local DOWNED = { IsRagdolled = true }

local function clear(holder: Instance?)
	if not holder then return end

	for _, child in holder:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(GlobalFunctions.CharacterService.MorphAbilityAttribute) ~= nil then
			child:Destroy()
		end
	end
end

local function usable(morph: Morph): boolean
	local StatusService = GlobalFunctions.StatusService
	local model = morph.Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not model.Parent or not humanoid or humanoid.Health <= 0 then return false end

	return not (StatusService:IsHitYielded(model) or StatusService:IsActionLocked(model) or StatusService:CheckStatuses(model, DOWNED))
end

local function strike(morph: Morph, spec: Spec): number
	local model = morph.Model
	local root = model.PrimaryPart
	if not root then return 0 end

	local look = root.CFrame.LookVector
	local from = root.Position + look * (spec.reach_from or 0)
	local to = root.Position + look * spec.reach
	local attacker = { Model = model, Config = morph.Profile.Config }
	local hits = 0

	for _, victim in Strike.Along(model, from, to, spec.radius) do
		if Attacks.Hit(attacker, victim, spec) then
			hits += 1
		end
	end

	return hits
end

function Abilities.Grant(morph: Morph)
	local CharacterService = GlobalFunctions.CharacterService
	local backpack = morph.Player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	clear(backpack)
	clear(morph.Model)
	table.clear(morph.Tools)

	for _, name in morph.Profile.AbilityOrder do
		local spec = morph.Profile.Abilities[name]
		local label = Profile.Label(name)
		local tool = Instance.new("Tool")

		tool.Name = label
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		tool.ToolTip = `{label}: {spec.ability_cooldown or 0}s cooldown`
		tool:SetAttribute(CharacterService.MorphAbilityAttribute, name)
		tool:SetAttribute(CharacterService.MorphReadyAttribute, 0)
		tool.Parent = backpack

		morph.Tools[name] = tool
	end
end

function Abilities.Use(morph: Morph, name: unknown, settings: Settings, reply: (name: string, result: Result) -> ())
	if typeof(name) ~= "string" then return end

	local spec = morph.Profile.Abilities[name]
	if not spec then return end

	local now = os.clock()

	if not usable(morph) or now < (morph.ReadyAt[name] or 0) or not Strike.Free(morph, now, settings) then
		reply(name, "Rejected")
		return
	end

	local cooldown = spec.ability_cooldown or 0
	local use: Types.Use = { Name = name, Spec = spec, At = now }
	local tool = morph.Tools[name]

	morph.Ability = use
	morph.ReadyAt[name] = now + cooldown

	if tool then
		tool:SetAttribute(GlobalFunctions.CharacterService.MorphReadyAttribute, workspace:GetServerTimeNow() + cooldown)
	end

	GlobalFunctions.StatusService:SetStatus(morph.Model, ATTACKING, true, spec.windup + spec.recovery)

	task.delay(spec.windup, function()
		if morph.Ability ~= use then return end

		if not usable(morph) then
			reply(name, "Interrupted")
			return
		end

		reply(name, if strike(morph, spec) > 0 then "Landed" else "Missed")
	end)
end

return Abilities
