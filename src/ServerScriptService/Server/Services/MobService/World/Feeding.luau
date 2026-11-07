local Jloader = require("@game/ReplicatedStorage/JLoader")
local CorpseLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/CorpseLibrary")

local Feeding = {}

local SETTLED_SPEED = 4
local KEEP_RANGE = 1.25
local SCENE = "InPairScene"

local eaters = setmetatable({}, { __mode = "k" })
local corpseService = nil

function Feeding.Corpses()
	corpseService = corpseService or Jloader.GetService("CorpseService")
	return corpseService
end

function Feeding.TorsoOf(corpse: Model?): BasePart?
	local torso = corpse and corpse:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

local function others(corpse: Model, except): number
	local count = 0

	for mob in eaters[corpse] or {} do
		if mob ~= except and not mob.Dead then
			count += 1
		end
	end

	return count
end

function Feeding.Edible(mob, corpse: Model): boolean
	local torso = Feeding.TorsoOf(corpse)
	if not torso or corpse:GetAttribute(SCENE) then return false end

	if mob.Blackboard.Chewing == corpse then return true end

	if CorpseLibrary.Dismember then
		if #Feeding.Corpses():Limbs(corpse) == 0 then return false end
	elseif mob.Blackboard.Finished and mob.Blackboard.Finished[corpse] then
		return false
	end

	if eaters[corpse] and eaters[corpse][mob] then return true end
	if torso.AssemblyLinearVelocity.Magnitude > SETTLED_SPEED then return false end

	return others(corpse, mob) < (mob.Config.feed.feeders or 1)
end

function Feeding.Find(mob): Model?
	local feed = mob.Config.feed
	local service = Feeding.Corpses()
	local previous = mob.Blackboard.Food
	local current = service:Resolve(previous)
	local currentTorso = Feeding.TorsoOf(current)

	if current and previous ~= current and eaters[previous] and eaters[previous][mob] then
		Feeding.Leave(mob, previous)
		Feeding.Join(mob, current)
	end

	if current and currentTorso and mob:DistanceTo(currentTorso.Position) <= feed.range * KEEP_RANGE and Feeding.Edible(mob, current) then
		return current
	end

	local best, bestDistance = nil, feed.range

	for _, corpse in service:GetCorpses() do
		local torso = Feeding.TorsoOf(corpse)
		local distance = torso and mob:DistanceTo(torso.Position)

		if distance and distance <= bestDistance and Feeding.Edible(mob, corpse) then
			best, bestDistance = corpse, distance
		end
	end

	return best
end

local function publish(corpse: Model)
	corpse:SetAttribute(CorpseLibrary.FeedersAttribute, others(corpse, nil))
end

function Feeding.Join(mob, corpse: Model?)
	if not corpse then return end

	local set = eaters[corpse] or setmetatable({}, { __mode = "k" })
	eaters[corpse] = set
	set[mob] = true
	publish(corpse)
end

function Feeding.Leave(mob, corpse: Model?)
	local set = corpse and eaters[corpse]

	if set then
		set[mob] = nil
		publish(corpse)
	end
end

return Feeding
