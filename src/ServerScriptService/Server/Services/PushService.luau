local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local PushLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/PushLibrary")

local PushService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "ReportPush", "ReportHit", "ReportLunge" } },
})

PushService.Settings = {
	--@ Seconds. A push is accepted this much sooner than PushLibrary.Cooldown, for jitter.
	CooldownLeniency = 0.2,

	--@ Studs. A push reported on a victim further than this is dropped as implausible.
	MaxReportDistance = 14,
}

--@ The push each player last started: { Sprinting, Fast, At, Hit }. One victim per push.
local pushes = {}

local combatService = nil

local function getCombatService()
	combatService = combatService or Jloader.GetService("CombatService")
	return combatService
end

local blockService = nil

local function getBlockService()
	blockService = blockService or Jloader.GetService("BlockService")
	return blockService
end

local effectRelay = nil

local function getEffectRelay()
	effectRelay = effectRelay or Jloader.GetService("EffectService")
	return effectRelay
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isFast(root: BasePart?): boolean
	if not root then return false end

	return (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude >= PushLibrary.Sprint.MinSpeed
end

--@ A sprint the server only started to see after the push began still counts: the pusher keeps
--@ sprint-push speed through it, where a standing push slows to a crawl.
local function variantOf(push, character: Model)
	local sprinting = push.Sprinting and (push.Fast or isFast(rootOf(character)))

	return sprinting and PushLibrary.Sprint or PushLibrary.Stand
end

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

function PushService:Apply(attacker: Model, victim: Model): boolean
	local StatusService = GlobalFunctions.StatusService

	if not rootOf(attacker) or not rootOf(victim) then return false end
	if not StatusService:IsAlive(victim) or StatusService:IsHitImmune(victim) then return false end
	if StatusService:IsHitYielded(attacker) then return false end

	if not PushLibrary.ThroughGuard and getBlockService():Absorb(attacker, victim) then
		return false
	end

	local direction = GlobalFunctions.PositionService.Aim(attacker, victim)
	if direction.Magnitude <= 0 then return false end

	return getCombatService():ApplyFinisher(victim, direction, PushLibrary.Launch)
end

function PushService:HandlePush(player: Player, sprinting)
	if typeof(sprinting) ~= "boolean" then return end

	local StatusService = GlobalFunctions.StatusService
	local character = player and player.Character
	local root = rootOf(character)

	if not root then return end
	if not StatusService:IsAlive(character) or StatusService:IsHitYielded(character) then return end

	local now = os.clock()
	local last = pushes[player]

	if last and now - last.At < PushLibrary.Cooldown - self.Settings.CooldownLeniency then return end

	pushes[player] = { Sprinting = sprinting, Fast = isFast(root), At = now, Hit = false }
end

function PushService:HandleHit(player: Player, victim)
	local push = pushes[player]
	local attacker = player and player.Character

	if not push or push.Hit or not attacker then return end

	local variant = variantOf(push, attacker)

	if os.clock() - push.At > variant.Window then return end

	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return end
	if victim == attacker or not victim:FindFirstChildOfClass("Humanoid") then return end

	local living = livingFolder()
	if not living or not victim:IsDescendantOf(living) then return end

	local attackerRoot, victimRoot = rootOf(attacker), rootOf(victim)
	if not attackerRoot or not victimRoot then return end

	if (victimRoot.Position - attackerRoot.Position).Magnitude > self.Settings.MaxReportDistance then return end

	push.Hit = true

	if not self:Apply(attacker, victim) then return end

	local payload = GlobalFunctions.AttackService:HitPayload(attacker, victim, variant.Hitbox.effect, "Push", 1, PushLibrary.Reaction)

	getEffectRelay().CreateVisual:FireExcept(player, payload)
end

--@ The pusher's own client drives its step forward; everyone else is sent the same recipe so they
--@ draw it in time instead of watching it arrive through replication, as with a light attack's lunge.
function PushService:HandleLunge(player: Player, payload)
	local push = pushes[player]
	local character = player and player.Character

	if not push or push.Lunged or not rootOf(character) then return end
	if typeof(payload) ~= "table" then return end

	local numbers = table.create(3)

	for index = 1, 3 do
		local value = tonumber(payload[index])
		if not value or value ~= value or math.abs(value) == math.huge then return end
		numbers[index] = value
	end

	local direction = Vector3.new(numbers[1], 0, numbers[3])
	if direction.Magnitude <= 1e-3 then return end

	local variant = variantOf(push, character)

	if not variant.Impulse or os.clock() - push.At > variant.Window then return end

	push.Lunged = true

	local KnockbackService = GlobalFunctions.KnockbackService
	local recipe = KnockbackService.Compose(character, direction.Unit, variant.Impulse, nil, KnockbackService.Active(character))

	if recipe then
		getCombatService().Knockback:FireExcept(player, character, recipe)
	end
end

function PushService:Init()
	self.ReportPush:Connect(function(player, sprinting)
		self:HandlePush(player, sprinting)
	end)

	self.ReportLunge:Connect(function(player, payload)
		self:HandleLunge(player, payload)
	end)

	self.ReportHit:Connect(function(player, victim)
		self:HandleHit(player, victim)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pushes[player] = nil
	end)
end

return PushService
