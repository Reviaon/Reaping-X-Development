local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local TackleLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/TackleLibrary")

local TackleService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "ReportTackle", "ReportHit", "Rejected" } },
})

local tackles = {}

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function livingFolder()
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function isAlive(character: Model): boolean
	return character.Parent ~= nil and GlobalFunctions.StatusService:IsAlive(character)
end

function TackleService:HandleTackle(player: Player)
	local StatusService = GlobalFunctions.StatusService
	local character = player and player.Character

	if not rootOf(character) then return end
	if not StatusService:IsAlive(character) or StatusService:IsHitYielded(character) then return end

	local now = os.clock()
	local last = tackles[player]

	if last and now - last.At < TackleLibrary.Cooldown - TackleLibrary.CooldownLeniency then return end

	tackles[player] = { At = now, Hit = false }
end

function TackleService:CheckHit(player: Player, victim, hitAt, variant): (string?, Model?, number?, {}?)
	local StatusService = GlobalFunctions.StatusService
	local PairSceneService = GlobalFunctions.PairSceneService
	local report = TackleLibrary.Report
	local tackle = tackles[player]
	local attacker = player and player.Character
	local definition = typeof(variant) == "string"
		and (TackleLibrary.Grapples[variant] or (variant == TackleLibrary.Impact.Variant and TackleLibrary.Impact))

	if not attacker then return "no character" end
	if not definition then return `unknown variant {tostring(variant)}` end
	if not tackle then return "no tackle on record" end
	if tackle.Hit then return "this tackle already caught someone" end
	if os.clock() - tackle.At > TackleLibrary.Leap.MaxFlight + definition.ConfirmWindow then return "the tackle on record is too old" end

	if typeof(hitAt) ~= "number" or hitAt ~= hitAt then return "bad hit time" end

	local age = workspace:GetServerTimeNow() - hitAt
	if age > report.MaxAge then return `report arrived {math.floor(age * 1000)}ms late` end

	if typeof(victim) ~= "Instance" or not victim:IsA("Model") or victim == attacker then return "bad victim" end

	local living = livingFolder()
	if not living or not victim:IsDescendantOf(living) then return `{victim.Name} is not in World.Live` end

	local attackerRoot, victimRoot = rootOf(attacker), rootOf(victim)
	if not attackerRoot or not victimRoot then return "missing root" end

	if not isAlive(attacker) then return "tackler is dead" end
	if not isAlive(victim) then return `{victim.Name} is dead` end
	if StatusService:IsHitYielded(attacker) then return "tackler is stunned" end
	if StatusService:IsHitImmune(victim) then return `{victim.Name} is hit-immune` end
	if PairSceneService.SceneOf(attacker) then return "tackler is already in a scene" end
	if PairSceneService.SceneOf(victim) then return `{victim.Name} is already in a scene` end

	local impact = definition == TackleLibrary.Impact
	if impact and PairSceneService.Supports(victim) then return `{victim.Name} can be grappled, not knocked down` end
	if not impact and not PairSceneService.Supports(victim) then return `{victim.Name} can't be grappled` end

	local distance = GlobalFunctions.PositionService.SurfaceDistance(attackerRoot.Position, victim)
	if distance > report.MaxDistance then return `{victim.Name} is {math.floor(distance)} studs away on the server` end

	return nil, attacker, math.max(age, 0), definition
end

function TackleService:Impact(attacker: Model, victim: Model)
	local impact = TackleLibrary.Impact
	local CombatService = Jloader.GetService("CombatService")
	local offset = rootOf(victim).Position - rootOf(attacker).Position
	local direction = Vector3.new(offset.X, 0, offset.Z)

	if direction.Magnitude <= 0 then
		direction = rootOf(attacker).CFrame.LookVector * Vector3.new(1, 0, 1)
	end

	CombatService:SceneStrike(victim, { Damage = impact.Damage })
	CombatService:ApplyFinisher(victim, direction.Unit, impact.Launch)
	CombatService.Provoked:Fire(attacker, victim)
end

function TackleService:HandleHit(player: Player, victim, hitAt, variant)
	local rejection, attacker, age, definition = self:CheckHit(player, victim, hitAt, variant)

	if not rejection then
		tackles[player].Hit = true

		if definition == TackleLibrary.Impact then
			self:Impact(attacker, victim)
			return
		end

		local scene, problem = GlobalFunctions.PairSceneService:Begin(definition, attacker, victim, { Age = age, Predicted = true })
		if scene then return end

		rejection = problem or "the scene could not start"
	end

	if GlobalFunctions.DebugService.IsEnabled() then
		warn(`[Tackle] {player.Name}'s grab was rejected: {rejection}`)
	end

	self.Rejected:Fire(player, rejection)
end

function TackleService:Init()
	self.ReportTackle:Connect(function(player)
		self:HandleTackle(player)
	end)

	self.ReportHit:Connect(function(player, victim, hitAt, variant)
		self:HandleHit(player, victim, hitAt, variant)
	end)

	Players.PlayerRemoving:Connect(function(player)
		tackles[player] = nil
	end)
end

return TackleService
