local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local StruggleLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/StruggleLibrary")

local StruggleService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "Begin", "Click", "Ended" } },
})

local struggles = {}
local nextId = 0

local function weightedCount(profile): number
	local total = 0

	for _, wave in profile.Waves do
		total += wave.Weight
	end

	local roll = math.random() * total

	for _, wave in profile.Waves do
		roll -= wave.Weight
		if roll <= 0 then return wave.Count end
	end

	return profile.Waves[1].Count
end

local function placeWave(profile, count: number): { Vector2 }
	local area = profile.Area
	local points = {}

	for _ = 1, count do
		local chosen = nil

		for _ = 1, profile.PlacementTries do
			local candidate = Vector2.new(
				area.Min.X + math.random() * (area.Max.X - area.Min.X),
				area.Min.Y + math.random() * (area.Max.Y - area.Min.Y)
			)

			local clear = true

			for _, point in points do
				if (point - candidate).Magnitude < profile.MinSpacing then
					clear = false
					break
				end
			end

			chosen = candidate

			if clear then break end
		end

		table.insert(points, chosen)
	end

	return points
end

local function pickKeys(profile, count: number): { string }
	local pool = table.clone(profile.Keys)
	local keys = {}

	for _ = 1, count do
		local index = math.random(#pool)
		table.insert(keys, pool[index])
		table.remove(pool, index)

		if #pool == 0 then
			pool = table.clone(profile.Keys)
		end
	end

	return keys
end

local function buildSchedule(profile, startAt: number, endsAt: number): { any }
	local dots = {}
	local threshold = math.min(profile.InnerScale + (profile.HitLeeway or 0), profile.StartScale)
	local hitFrom = profile.ShrinkTime * (profile.StartScale - threshold) / (profile.StartScale - profile.EndScale)
	local spawnAt = startAt

	while spawnAt + profile.ShrinkTime <= endsAt do
		local count = weightedCount(profile)
		local points = placeWave(profile, count)
		local keys = pickKeys(profile, count)

		for index = 1, count do
			table.insert(dots, {
				Id = #dots + 1,
				SpawnAt = spawnAt,
				HitFrom = spawnAt + hitFrom,
				HitUntil = spawnAt + profile.ShrinkTime,
				X = points[index].X,
				Y = points[index].Y,
				Key = keys[index],
			})
		end

		spawnAt += profile.WaveSpacing
	end

	return dots
end

local function scheduleNpc(profile, participant)
	local npc = profile.Npc
	local plays = {}

	for _, dot in participant.Dots do
		if math.random() < npc.Accuracy then
			local at = dot.HitFrom + npc.Reaction.Min + math.random() * (npc.Reaction.Max - npc.Reaction.Min)
			table.insert(plays, { At = math.min(at, dot.HitUntil), Dot = dot.Id })
		end
	end

	table.sort(plays, function(a, b)
		return a.At < b.At
	end)

	participant.Plays = plays
end

local function judge(struggle, participant, dotId: number, at: number)
	local dot = participant.Dots[dotId]
	if not dot or participant.Judged[dotId] then return end

	local profile = struggle.Profile

	if at < dot.SpawnAt or at > dot.HitUntil + profile.Tolerance then return end

	participant.Judged[dotId] = true

	if at >= dot.HitFrom and at <= dot.HitUntil then
		participant.Score += profile.PointsPerHit
	else
		participant.Score += profile.PointsPerMiss
	end

	if participant.Score >= profile.TargetScore then
		StruggleService:Finish(struggle, `{participant.Character.Name} reached {profile.TargetScore}`)
	end
end

function StruggleService:Start(scene)
	local profile = StruggleLibrary.Profiles[scene.Definition.Struggle]
	if not profile then return nil end

	scene.EndsAt = nil
	nextId += 1

	local now = workspace:GetServerTimeNow()
	local startAt = now + profile.StartDelay
	local endsAt = startAt + profile.TimeLimit

	local struggle = {
		Id = nextId,
		Scene = scene,
		Profile = profile,
		ProfileName = scene.Definition.Struggle,
		StartAt = startAt,
		EndsAt = endsAt,
		Participants = {},
	}

	for _, entry in { { scene.Attacker, "Attacker" }, { scene.Victim, "Victim" } } do
		local character, role = entry[1], entry[2]

		local participant = {
			Character = character,
			Role = role,
			Player = Players:GetPlayerFromCharacter(character),
			Score = 0,
			Judged = {},
			Dots = buildSchedule(profile, startAt, endsAt),
		}

		if participant.Player then
			self.Begin:Fire(participant.Player, {
				Id = struggle.Id,
				Profile = struggle.ProfileName,
				StartAt = startAt,
				EndsAt = endsAt,
				Dots = participant.Dots,
			})
		else
			scheduleNpc(profile, participant)
		end

		struggle.Participants[role] = participant
	end

	struggles[struggle.Id] = struggle

	return struggle
end

function StruggleService:Finish(struggle, reason: string)
	if struggles[struggle.Id] ~= struggle then return end

	struggles[struggle.Id] = nil

	local attacker, victim = struggle.Participants.Attacker, struggle.Participants.Victim
	local margin = attacker.Score - victim.Score
	local outcome = if math.abs(margin) <= struggle.Profile.CloseMargin then "Draw" elseif margin > 0 then "AttackerWins" else "AttackerLoses"

	if GlobalFunctions.DebugService.IsEnabled() then
		warn(`[Struggle] {struggle.Scene.Id}: {attacker.Character.Name} {attacker.Score} - {victim.Score} {victim.Character.Name} ({reason}) -> {outcome}`)
	end

	for _, participant in { attacker, victim } do
		if participant.Player then
			self.Ended:Fire(participant.Player, struggle.Id, outcome)
		end
	end

	GlobalFunctions.PairSceneService:Resolve(struggle.Scene, outcome)
end

function StruggleService:Abort(struggle)
	if struggles[struggle.Id] ~= struggle then return end

	struggles[struggle.Id] = nil

	for _, participant in struggle.Participants do
		if participant.Player then
			self.Ended:Fire(participant.Player, struggle.Id, nil)
		end
	end
end

function StruggleService:HandleClick(player: Player, id, dotId, at)
	if typeof(id) ~= "number" or typeof(dotId) ~= "number" or typeof(at) ~= "number" or at ~= at then return end

	local struggle = struggles[id]
	if not struggle then return end

	local participant = nil

	for _, candidate in struggle.Participants do
		if candidate.Player == player then
			participant = candidate
		end
	end

	if not participant then return end

	local received = workspace:GetServerTimeNow()

	judge(struggle, participant, dotId, math.clamp(at, received - struggle.Profile.Tolerance, received))
end

local function step()
	local now = workspace:GetServerTimeNow()
	local PairSceneService = GlobalFunctions.PairSceneService

	for _, struggle in struggles do
		local scene = struggle.Scene

		if PairSceneService.SceneOf(scene.Attacker) ~= scene or PairSceneService.SceneOf(scene.Victim) ~= scene then
			StruggleService:Abort(struggle)
			continue
		end

		for _, participant in struggle.Participants do
			local plays = participant.Plays

			while plays and plays[1] and plays[1].At <= now do
				local play = table.remove(plays, 1)
				judge(struggle, participant, play.Dot, play.At)

				if struggles[struggle.Id] ~= struggle then break end
			end
		end

		if struggles[struggle.Id] == struggle and now >= struggle.EndsAt then
			StruggleService:Finish(struggle, "time limit")
		end
	end
end

function StruggleService:Init()
	GlobalFunctions.PairSceneService.Started:Connect(function(scene)
		self:Start(scene)
	end)

	self.Click:Connect(function(player, id, dotId, at)
		self:HandleClick(player, id, dotId, at)
	end)

	RunService.Heartbeat:Connect(step)
end

return StruggleService
