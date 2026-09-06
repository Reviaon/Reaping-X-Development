local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local CombatService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "ReportHit", "Knockback", "ReportRoot" } },
})

local CombatConfig = require(
	ReplicatedStorage:WaitForChild("Modules")
		:WaitForChild("Client")
		:WaitForChild("Controllers")
		:WaitForChild("Character")
		:WaitForChild("CombatHandler")
		:WaitForChild("Config")
)

CombatService.Settings = {
	--@ Studs. A hit reported from further than this is dropped as implausible.
	MaxReportDistance = 60,

	--@ Seconds. Floor on how often one attacker may report a hit on the same victim.
	ReportCooldown = 0.05,

	--@ Seconds. Floor on how often one player's root report is accepted.
	RootReportCooldown = 0.05,

	--@ Seconds a hit victim is stunned. 0 disables.
	HitstunDuration = 0.25,
}

local lastReport = {}
local lastRootReport = {}

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function knockbackDirection(attacker: Model, victim: Model): Vector3
	local PositionService = GlobalFunctions.PositionService

	local attackerPosition, attackerLook = PositionService.Reference(attacker)
	local victimPosition = PositionService.Reference(victim)

	if not attackerPosition or not victimPosition then
		return Vector3.zero
	end

	local offset = (victimPosition - attackerPosition) * Vector3.new(1, 0, 1)

	if offset.Magnitude > 0 then
		return offset.Unit
	end

	local fallback = (attackerLook or Vector3.zAxis) * Vector3.new(1, 0, 1)

	return fallback.Magnitude > 0 and fallback.Unit or Vector3.zero
end

function CombatService:ResolveKnockback(weaponId: string, comboIndex: number)
	local weaponConfig = CombatConfig.WeaponConfig[weaponId]
	if not weaponConfig then return nil end

	local timing = CombatConfig:ResolveAttackTiming(nil, comboIndex, weaponConfig)
	local knockback = timing.knockback

	if not knockback or knockback.enabled == false then return nil end

	return knockback
end

function CombatService:ApplyKnockback(attacker: Model, victim: Model, profile, weaponId: string, comboIndex: number)
	local knockback = self:ResolveKnockback(weaponId, comboIndex)
	if not knockback then return false end

	profile = profile or GlobalFunctions.ServerController:GetProfile(victim)
	if not profile then return false end

	if not rootOf(attacker) or not rootOf(victim) then return false end

	local direction = knockbackDirection(attacker, victim)
	if direction.Magnitude <= 0 then return false end

	local KnockbackService = GlobalFunctions.KnockbackService

	--@ direction runs attacker -> victim, so the victim looks back along it.
	local facing = knockback.face ~= false and -direction or nil

	local recipe = KnockbackService.Build(victim, direction, {
		speed = knockback.speed,
		duration = knockback.duration,
		falloff = knockback.falloff,
		rampIn = knockback.rampIn,
		distance = knockback.distance,
		priority = knockback.priority,
	}, facing)

	if not recipe then return false end

	local hitstun = self.Settings.HitstunDuration

	if hitstun > 0 then
		GlobalFunctions.StatusService:SetStatus(victim, "IsStunned", true, hitstun)
	end

	--@ Every client draws it; the server drives only what it owns. Fired before Apply so the
	--@ recipe is serialised exactly as built.
	self.Knockback:FireAll(victim, recipe)
	KnockbackService.Apply(victim, recipe)

	return true
end

function CombatService:HandleRootReport(player: Player, payload)
	local character = player and player.Character
	if not character then return end

	local now = os.clock()
	local last = lastRootReport[player]

	if last and now - last < self.Settings.RootReportCooldown then return end

	lastRootReport[player] = now

	GlobalFunctions.PositionService.Accept(character, payload)
end

function CombatService:HandleReport(player: Player, victim, weaponId, comboIndex, attackerRoot)
	local settings = self.Settings

	local attacker = player and player.Character
	if not attacker then return end

	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return end
	if victim == attacker then return end
	if not victim:FindFirstChildOfClass("Humanoid") then return end

	local living = livingFolder()
	if not living or not victim:IsDescendantOf(living) then return end

	if typeof(weaponId) ~= "string" then return end
	if typeof(comboIndex) ~= "number" or comboIndex < 1 then return end

	local attackerRootPart = rootOf(attacker)
	local victimRootPart = rootOf(victim)
	if not attackerRootPart or not victimRootPart then return end

	if (victimRootPart.Position - attackerRootPart.Position).Magnitude > settings.MaxReportDistance then
		return
	end

	local profile = GlobalFunctions.ServerController:GetProfile(victim)
	if not profile then return end

	local now = os.clock()
	local key = tostring(player.UserId) .. "|" .. tostring(profile.Id)

	if lastReport[key] and now - lastReport[key] < settings.ReportCooldown then
		return
	end

	lastReport[key] = now

	if attackerRoot ~= nil then
		GlobalFunctions.PositionService.Accept(attacker, attackerRoot)
	end

	self:ApplyKnockback(attacker, victim, profile, weaponId, math.floor(comboIndex))
end

function CombatService:Init()
	self.ReportHit:Connect(function(player, victim, weaponId, comboIndex, attackerRoot)
		self:HandleReport(player, victim, weaponId, comboIndex, attackerRoot)
	end)

	self.ReportRoot:Connect(function(player, payload)
		self:HandleRootReport(player, payload)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local prefix = tostring(player.UserId) .. "|"

		for key in lastReport do
			if string.sub(key, 1, #prefix) == prefix then
				lastReport[key] = nil
			end
		end

		lastRootReport[player] = nil

		if player.Character then
			GlobalFunctions.PositionService.Clear(player.Character)
		end
	end)
end

return CombatService
