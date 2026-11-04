local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local RangedService = Jloader.CreateService({
	Name = script.Name,
	Signals = {
		Remote = { "ReportShot", "ReportProjectileHit", "AimState", "AimPitch", "Shot" },
		Basic = { "Fired" },
	},
})

local CombatConfig = require("@game/ReplicatedStorage/Modules/Client/Controllers/Character/CombatHandler/Config")
local CorpseLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/CorpseLibrary")

RangedService.Settings = {
	OriginTolerance = 8,
	FireIntervalLeniency = 0.15,
	MaxClockSkew = 1,
	PathTolerance = 4,
	EarlyReportLeniency = 0.25,
	RewindWindow = 1,
	VictimTolerance = 3,
	HistoryLength = 1.2,
	LineOfSightStep = 1 / 30,
	ShotGrace = 2,
	AimStateCooldown = 1 / 20,
	AimPitchCooldown = 1 / 12,
	LimbTolerance = 3,
	SeverLift = 20,
	SeveredGroup = "Default",
	SeverClearTime = 0.2,
	MaxAimPitch = 90,
}

local AIM_PHASES = { Idle = true, Drawing = true, Holding = true, Firing = true, Reloading = true }

local shots = {}
local lastShot = {}
local lastAimState = {}
local lastAimPitch = {}
local history = {}

local combatService = nil

local function getCombatService()
	combatService = combatService or Jloader.GetService("CombatService")
	return combatService
end

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function visualsFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Visuals")
end

local function projectileOf(character: Model, weaponId)
	if typeof(weaponId) ~= "string" then return nil end
	if character:GetAttribute("EquippedWeapon") ~= weaponId then return nil end

	local data = CombatConfig.WeaponConfig[weaponId]
	return data and data.projectile
end

local function record()
	local living = livingFolder()
	if not living then return end

	local now = workspace:GetServerTimeNow()
	local cutoff = now - RangedService.Settings.HistoryLength

	for _, model in living:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local samples = history[model]

		if not samples then
			samples = {}
			history[model] = samples
		end

		table.insert(samples, { t = now, frame = root.CFrame })

		while samples[1] and samples[1].t < cutoff do
			table.remove(samples, 1)
		end
	end

	for model in history do
		if not model.Parent then
			history[model] = nil
		end
	end
end

local function boxDistance(frame: CFrame, size: Vector3, point: Vector3): number
	local relative = frame:PointToObjectSpace(point)
	local half = size / 2

	return Vector3.new(
		math.max(math.abs(relative.X) - half.X, 0),
		math.max(math.abs(relative.Y) - half.Y, 0),
		math.max(math.abs(relative.Z) - half.Z, 0)
	).Magnitude
end

local function nearestPast(victim: Model, from: number, to: number, point: Vector3): number
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then return math.huge end

	local frame, size = victim:GetBoundingBox()
	local offset = root.CFrame:ToObjectSpace(frame)
	local best = boxDistance(frame, size, point)

	for _, sample in history[victim] or {} do
		if sample.t >= from and sample.t <= to then
			best = math.min(best, boxDistance(sample.frame * offset, size, point))
		end
	end

	return best
end

local function pathClear(shot, flightTime: number, victim: Model): boolean
	local ignore = { shot.Shooter, victim }
	local living, visuals = livingFolder(), visualsFolder()

	if living then table.insert(ignore, living) end
	if visuals then table.insert(ignore, visuals) end

	local params = GlobalFunctions.ProjectileService.Params(shot, ignore)
	local step = RangedService.Settings.LineOfSightStep
	local t = 0

	while t < flightTime do
		local nextT = math.min(t + step, flightTime)
		local result = GlobalFunctions.ProjectileService.Cast(shot, t, nextT, params)

		if result then return false end

		t = nextT
	end

	return true
end

local function prune(player: Player, now: number)
	local list = shots[player]
	if not list then return end

	for id, shot in list do
		if now - shot.FiredAt > GlobalFunctions.ProjectileService.Lifetime(shot) + RangedService.Settings.ShotGrace then
			list[id] = nil
		end
	end
end

function RangedService:HandleShot(player: Player, weaponId, origin, direction, clientTime, localId)
	local settings = self.Settings
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local projectile = projectileOf(character, weaponId)
	if not projectile then return end

	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if typeof(clientTime) ~= "number" or typeof(localId) ~= "number" then return end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then return end
	if not GlobalFunctions.StatusService:IsAlive(character) then return end
	if GlobalFunctions.StatusService:IsHitYielded(character) then return end
	if (origin - root.Position).Magnitude > settings.OriginTolerance then return end

	local now = workspace:GetServerTimeNow()
	local tier = GlobalFunctions.ProjectileService.Tier(projectile, character)
	local speed = tier and tier.draw
	local interval = (if typeof(projectile.fire_interval) == "number" then projectile.fire_interval else 0)
		/ (if typeof(speed) == "number" and speed > 0 then speed else 1)

	if lastShot[player] and now - lastShot[player] < interval - settings.FireIntervalLeniency then return end

	prune(player, now)

	shots[player] = shots[player] or {}
	if shots[player][localId] then return end

	local shot = GlobalFunctions.ProjectileService.NewShot(origin, direction, projectile, character)
	shot.FiredAt = math.clamp(clientTime, now - settings.MaxClockSkew, now)
	shot.Weapon = weaponId

	shots[player][localId] = shot
	lastShot[player] = now

	self.Shot:FireExcept(player, character, weaponId, origin, shot.Direction, shot.FiredAt)
	self.Fired:Fire(character, origin, shot.Direction)
end

local function limbOf(victim: Model, limbName, hitPosition: Vector3): BasePart?
	if typeof(limbName) ~= "string" then return nil end

	local known = false

	for _, partName in CorpseLibrary.Limbs do
		if partName == limbName then
			known = true
			break
		end
	end

	local limb = known and victim:FindFirstChild(limbName)
	if not limb or not limb:IsA("BasePart") or limb:GetAttribute(CorpseLibrary.TakenAttribute) then return nil end

	local reach = limb.Size.Magnitude / 2 + RangedService.Settings.LimbTolerance

	return if (limb.Position - hitPosition).Magnitude <= reach then limb else nil
end

local function corpseFolder(): Instance
	local found = workspace

	for _, segment in CorpseLibrary.FolderPath do
		local child = found:FindFirstChild(segment)

		if not child then
			child = Instance.new("Folder")
			child.Name = segment
			child.Parent = found
		end

		found = child
	end

	return found
end

local function holderFor(victim: Model, limb: BasePart): Model
	local holder = Instance.new("Model")
	holder.Name = victim.Name .. " " .. limb.Name

	local humanoid = Instance.new("Humanoid")
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = holder

	for _, child in victim:GetChildren() do
		if child:IsA("Clothing") or child:IsA("BodyColors") then
			child:Clone().Parent = holder
		end
	end

	return holder
end

function RangedService:CarryLimb(victim: Model, limb: BasePart, velocity: Vector3, carry: number)
	GlobalFunctions.RagdollService.Sever(victim, limb)

	for _, part in victim:GetDescendants() do
		if part ~= limb and part:IsA("BasePart") then
			local ignore = Instance.new("NoCollisionConstraint")
			ignore.Part0 = limb
			ignore.Part1 = part
			ignore.Parent = limb
		end
	end

	local holder = holderFor(victim, limb)

	limb:SetAttribute(CorpseLibrary.TakenAttribute, true)
	limb.Parent = holder
	holder.PrimaryPart = limb
	holder.Parent = corpseFolder()

	limb.Anchored = false
	limb.CanCollide = false
	limb.CollisionGroup = self.Settings.SeveredGroup

	if limb:CanSetNetworkOwnership() then
		limb:SetNetworkOwner(nil)
	end

	local carried = velocity * carry
	limb.AssemblyLinearVelocity = Vector3.new(carried.X, math.max(carried.Y, 0) + self.Settings.SeverLift, carried.Z)
	Debris:AddItem(holder, CorpseLibrary.Lifetime)

	task.delay(self.Settings.SeverClearTime, function()
		if limb.Parent then
			limb.CanCollide = true
		end
	end)
end

local function refuse(reason: string)
	if GlobalFunctions.DebugService.IsEnabled() then
		warn(`[Ranged] Hit refused: {reason}`)
	end
end

function RangedService:HandleHit(player: Player, localId, victim, hitPosition, flightTime, limbName)
	local settings = self.Settings
	local character = player and player.Character
	if not character then return end

	local shot = shots[player] and shots[player][localId]
	if not shot or shot.Consumed or shot.Shooter ~= character then return refuse("unknown or spent shot") end

	if typeof(victim) ~= "Instance" or not victim:IsA("Model") or victim == character then return end
	if typeof(hitPosition) ~= "Vector3" or typeof(flightTime) ~= "number" then return end

	local living = livingFolder()
	if not living or victim.Parent ~= living then return refuse(`{victim.Name} is not under World.Live`) end
	if not victim:FindFirstChildOfClass("Humanoid") then return refuse(`{victim.Name} has no Humanoid`) end

	local lifetime = GlobalFunctions.ProjectileService.Lifetime(shot)
	if flightTime < 0 or flightTime > lifetime then return refuse("flight time out of range") end

	local now = workspace:GetServerTimeNow()
	local landed = shot.FiredAt + flightTime

	if now < landed - settings.EarlyReportLeniency then return refuse("reported before the arrow could land") end
	if now - landed > settings.RewindWindow + settings.ShotGrace then return refuse("report too late") end
	if GlobalFunctions.ProjectileService.Dodging(victim, landed, player:GetNetworkPing() / 2) then return refuse(`{victim.Name} sidestepped the shot`) end

	local offPath = (GlobalFunctions.ProjectileService.PathAt(shot, flightTime) - hitPosition).Magnitude
	if offPath > settings.PathTolerance then return refuse(string.format("%.1f studs off the path", offPath)) end

	local offBody = nearestPast(victim, landed - settings.RewindWindow, landed + settings.EarlyReportLeniency, hitPosition)
	if offBody > settings.VictimTolerance then return refuse(string.format("%.1f studs from %s", offBody, victim.Name)) end
	if not pathClear(shot, flightTime, victim) then return refuse("path blocked by the world") end

	local profile = GlobalFunctions.ServerController:GetProfile(victim)
	if not profile then return refuse(`{victim.Name} has no profile`) end

	shot.Consumed = true

	local velocity = GlobalFunctions.ProjectileService.VelocityAt(shot, flightTime)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local alive = humanoid.Health > 0
	local limb = limbOf(victim, limbName, hitPosition)

	local accepted = getCombatService():LandHit(character, victim, profile, shot.Weapon, 1, nil, {
		Point = hitPosition,
		Normal = if velocity.Magnitude > 0 then -velocity.Unit else Vector3.yAxis,
	})

	if not accepted then return refuse(`CombatService refused the hit on {victim.Name} (immune, guarding or dodging)`) end

	local data = CombatConfig.WeaponConfig[shot.Weapon]
	local carry = data and data.projectile and data.projectile.sever_carry

	if limb and alive and humanoid.Health <= 0 and typeof(carry) == "number" then
		self:CarryLimb(victim, limb, velocity, carry)
	end
end

function RangedService:HandleAimPitch(player: Player, pitch)
	local character = player and player.Character
	if not character or typeof(pitch) ~= "number" or pitch ~= pitch then return end

	local now = os.clock()
	if lastAimPitch[player] and now - lastAimPitch[player] < self.Settings.AimPitchCooldown and pitch ~= 0 then return end

	lastAimPitch[player] = now

	local limit = self.Settings.MaxAimPitch
	character:SetAttribute("ProjectilePitch", math.clamp(pitch, -limit, limit))
end

function RangedService:HandleAimState(player: Player, phase, nocked)
	local character = player and player.Character
	if not character then return end
	if typeof(phase) ~= "string" or not AIM_PHASES[phase] then return end

	local now = os.clock()
	if lastAimState[player] and now - lastAimState[player] < self.Settings.AimStateCooldown and phase ~= "Idle" then return end

	lastAimState[player] = now

	character:SetAttribute("ProjectileState", phase)
	character:SetAttribute("ProjectileNocked", nocked == true)
	character:SetAttribute("ProjectileStateAt", workspace:GetServerTimeNow())
end

function RangedService:Init()
	self.ReportShot:Connect(function(player, ...)
		self:HandleShot(player, ...)
	end)

	self.ReportProjectileHit:Connect(function(player, ...)
		self:HandleHit(player, ...)
	end)

	self.AimState:Connect(function(player, ...)
		self:HandleAimState(player, ...)
	end)

	self.AimPitch:Connect(function(player, ...)
		self:HandleAimPitch(player, ...)
	end)

	RunService.Heartbeat:Connect(record)

	Players.PlayerRemoving:Connect(function(player)
		shots[player] = nil
		lastShot[player] = nil
		lastAimState[player] = nil
		lastAimPitch[player] = nil
	end)
end

return RangedService
