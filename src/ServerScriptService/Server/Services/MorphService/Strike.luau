--!strict

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Attacks = require("../MobService/Combat/Attacks")
local Types = require("./Types")

type Morph = Types.Morph
type Settings = Types.Settings

local Strike = {}

local GlobalFunctions = Jloader.GlobalFunctions

local combatService: any = nil
local blockService: any = nil

local function combat(): any
	combatService = combatService or Jloader.GetService("CombatService")
	return combatService
end

local function block(): any
	blockService = blockService or Jloader.GetService("BlockService")
	return blockService
end

local function live(): Instance?
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function victimOf(value: unknown, model: Model, living: Instance): Model?
	if typeof(value) ~= "Instance" or not value:IsA("Model") or value == model then return nil end
	if not value:IsDescendantOf(living) or not value:FindFirstChildOfClass("Humanoid") then return nil end
	if GlobalFunctions.StatusService:IsHitImmune(value) then return nil end

	return value
end

local function segmentDistance(point: Vector3, from: Vector3, to: Vector3): number
	local axis = to - from
	local length = axis:Dot(axis)
	local along = if length > 1e-6 then math.clamp((point - from):Dot(axis) / length, 0, 1) else 0

	return (point - (from + axis * along)).Magnitude
end

function Strike.Free(morph: Morph, now: number, settings: Settings): boolean
	local swing = morph.Swing
	local ability = morph.Ability

	if swing and now - swing.At < (swing.Spec.windup + swing.Spec.recovery) * settings.SwingSlack then return false end
	if ability and now - ability.At < (ability.Spec.windup + ability.Spec.recovery) * settings.SwingSlack then return false end

	return true
end

function Strike.Along(model: Model, from: Vector3, to: Vector3, radius: number): { Model }
	local living = live()
	local found: { Model } = {}
	local distances: { [Model]: number } = {}

	if not living then return found end

	for _, child in living:GetChildren() do
		if child == model or not child:IsA("Model") then continue end

		local humanoid = child:FindFirstChildOfClass("Humanoid")
		local root = child:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then continue end

		local distance = segmentDistance(root.Position, from, to)

		if distance <= radius then
			distances[child] = (root.Position - from).Magnitude
			table.insert(found, child)
		end
	end

	table.sort(found, function(a: Model, b: Model): boolean
		return distances[a] < distances[b]
	end)

	return found
end

function Strike.Swing(morph: Morph, index: unknown, settings: Settings)
	if typeof(index) ~= "number" then return end

	local spec = morph.Profile.Specs[index]
	local model = morph.Model

	if not spec or not model.Parent then return end
	if GlobalFunctions.StatusService:IsHitYielded(model) then return end

	local now = os.clock()

	if not Strike.Free(morph, now, settings) then return end

	morph.Swing = { Index = index, Spec = spec, At = now, Landed = false }

	block():BeginSwing(model, spec.windup + spec.recovery)
	combat().Swung:Fire(model)
end

function Strike.Land(morph: Morph, index: unknown, victims: unknown, root: unknown, settings: Settings): number
	local swing = morph.Swing
	if not swing or swing.Index ~= index or swing.Landed or typeof(victims) ~= "table" then return 0 end

	local spec = swing.Spec
	local elapsed = os.clock() - swing.At

	if elapsed < spec.windup * settings.EarlyStrike or elapsed > spec.windup + spec.recovery + settings.LateStrike then return 0 end

	swing.Landed = true

	local model = morph.Model
	local rootPart = model.PrimaryPart
	local living = live()

	if not rootPart or not living then return 0 end

	if root ~= nil then
		GlobalFunctions.PositionService.Accept(model, root)
	end

	local attacker = { Model = model, Config = morph.Profile.Config }
	local limit = spec.reach + spec.radius + settings.StrikeTolerance
	local seen: { [Model]: boolean } = {}
	local hits = 0

	for position, value in victims :: { [unknown]: unknown } do
		if typeof(position) ~= "number" or position > settings.MaxVictims then continue end

		local victim = victimOf(value, model, living)
		if not victim or seen[victim] then continue end

		seen[victim] = true

		if GlobalFunctions.PositionService.SurfaceDistance(rootPart.Position, victim) > limit then continue end

		if Attacks.Hit(attacker, victim, spec) then
			hits += 1
			combat().Provoked:Fire(model, victim, spec.damage)
		end
	end

	return hits
end

return Strike
