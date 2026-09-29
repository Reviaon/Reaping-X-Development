local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local BlockLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/BlockLibrary")

local BlockService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "ReportBlock", "Guard" } },
})

--@ Health below MaxHealth, kept unrounded so regen isn't lost to the rounded attribute. A character
--@ is only in here while it has something to regenerate.
local pool = setmetatable({}, { __mode = "k" })
local lastAbsorbedAt = setmetatable({}, { __mode = "k" })

--@ Whoever the raised guard last absorbed a hit from.
local absorbedFrom = setmetatable({}, { __mode = "k" })

--@ Opened when that guard is lowered: { Attacker, OpenUntil, Until }. Until is set by the first
--@ swing inside the window and ends with that swing.
local counters = setmetatable({}, { __mode = "k" })

local function healthOf(character)
	local stored = pool[character]
	if stored then return stored end

	local health = character:GetAttribute(BlockLibrary.HealthAttribute)
	return typeof(health) == "number" and health or BlockLibrary.MaxHealth
end

local function publish(character, health)
	health = math.clamp(health, 0, BlockLibrary.MaxHealth)
	pool[character] = health < BlockLibrary.MaxHealth and health or nil

	local shown = math.floor(health)

	if character:GetAttribute(BlockLibrary.HealthAttribute) ~= shown then
		character:SetAttribute(BlockLibrary.HealthAttribute, shown)
	end
end

local function regenerate(deltaTime)
	local now = os.clock()

	for character, health in pool do
		if not character.Parent then
			pool[character] = nil
			continue
		end

		if character:GetAttribute(BlockLibrary.BrokenStatus) == true then continue end
		if now - (lastAbsorbedAt[character] or 0) < BlockLibrary.RegenDelay then continue end

		publish(character, health + BlockLibrary.RegenRate * deltaTime)
	end
end

local function notify(character, event)
	local player = Players:GetPlayerFromCharacter(character)

	if player then
		BlockService.Guard:Fire(player, event)
	end
end

local effectRelay = nil

local function getEffectRelay()
	effectRelay = effectRelay or Jloader.GetService("EffectService")
	return effectRelay
end

local function openCounter(character)
	local attacker = absorbedFrom[character]
	absorbedFrom[character] = nil

	if attacker then
		counters[character] = { Attacker = attacker, OpenUntil = os.clock() + BlockLibrary.CounterWindow }
	end
end

function BlockService:CanGuard(character)
	local StatusService = GlobalFunctions.StatusService

	return StatusService:IsAlive(character) and not StatusService:IsHitYielded(character)
end

function BlockService:SetGuard(character, raised)
	local StatusService = GlobalFunctions.StatusService

	if raised and self:CanGuard(character) then
		counters[character] = nil
		StatusService:SetStatus(character, BlockLibrary.GuardStatus, true)
		return true
	end

	if character:GetAttribute(BlockLibrary.GuardStatus) ~= nil then
		StatusService:RemoveStatus(character, BlockLibrary.GuardStatus)
		openCounter(character)
	end

	return false
end

function BlockService:Break(character)
	local StatusService = GlobalFunctions.StatusService

	absorbedFrom[character] = nil
	counters[character] = nil

	StatusService:RemoveStatus(character, BlockLibrary.GuardStatus)
	StatusService:ApplyStatus(character, BlockLibrary.BrokenStatus, true, BlockLibrary.BreakLockout)

	getEffectRelay().CreateVisual:FireAll({
		Effect = BlockLibrary.DazeEffect,
		Method = "Attach",
		Info = {
			Character = character,
			Until = workspace:GetServerTimeNow() + BlockLibrary.BreakLockout,
		},
	})

	task.delay(BlockLibrary.BreakLockout, function()
		if character.Parent then
			publish(character, BlockLibrary.MaxHealth)
		end
	end)
end

--@ True when the victim's guard took the hit; the caller then applies nothing else.
function BlockService:Absorb(attacker, victim)
	if not GlobalFunctions.StatusService:IsGuarding(victim) then return false end

	local health = healthOf(victim) - BlockLibrary.HitCost

	lastAbsorbedAt[victim] = os.clock()
	absorbedFrom[victim] = attacker
	publish(victim, health)

	if health <= 0 then
		self:Break(victim)
		notify(victim, "Broken")
	else
		notify(victim, "Absorbed")
	end

	return true
end

--@ A swing starting inside an open counter window claims it for the swing's duration.
function BlockService:BeginSwing(character, duration)
	local counter = counters[character]
	if not counter or counter.Until then return end

	local now = os.clock()

	if now > counter.OpenUntil then
		counters[character] = nil
		return
	end

	counter.Until = now + duration
end

--@ True while character's counter swing outranks attacker's hits.
function BlockService:HasPriority(character, attacker)
	local counter = counters[character]
	if not counter or counter.Attacker ~= attacker or not counter.Until then return false end

	if os.clock() > counter.Until then
		counters[character] = nil
		return false
	end

	return true
end

function BlockService:HandleReport(player, raised)
	if typeof(raised) ~= "boolean" then return end

	local character = player and player.Character
	if not character or not character:FindFirstChildOfClass("Humanoid") then return end

	if not self:SetGuard(character, raised) and raised then
		notify(character, "Refused")
	end
end

function BlockService:Init()
	self.ReportBlock:Connect(function(player, raised)
		self:HandleReport(player, raised)
	end)

	RunService.Heartbeat:Connect(regenerate)
end

return BlockService
