local CorpseLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/CorpseLibrary")
local Attacks = require("../../Combat/Attacks")
local Feeding = require("../../World/Feeding")

local REFRESH = 0.25
local ARRIVE_DISTANCE = 2
local DRIFT_DISTANCE = 4
local REMOVE_MARKER = "RemoveLimb"
local RELEASE_MARKER = "ReleaseLimb"
local FEEDING = "IsFeeding"

local random = Random.new()

local function letGo(mob, data)
	local held = data.Held
	data.Held = nil
	mob.Blackboard.Chewing = nil

	if not held then return end

	local service = Feeding.Corpses()
	local limb = service:Find(data.Food, held)
	if not limb then return end

	if data.Swallow then
		service:Consume(limb)
	else
		service:Drop(limb)
	end
end

local function bite(mob, data)
	if data.Held or not CorpseLibrary.Dismember then return end

	local service = Feeding.Corpses()
	local corpse = service:Resolve(data.Food)
	if not corpse then return end

	local joints = service:Limbs(corpse)
	if #joints == 0 then return end

	local feed = mob.Config.feed
	local carry = feed.carry

	data.Held = service:Take(corpse, joints[random:NextInteger(1, #joints)], mob.Model, carry.bone, carry.offset)
	data.Swallow = random:NextNumber() < (feed.swallow_chance or 0)

	if data.Held then
		mob.Blackboard.Chewing = corpse
	end
end

local function stopEating(mob, data)
	for _, connection in data.Markers or {} do
		connection:Disconnect()
	end

	data.Markers = nil

	if data.Track then
		mob.Animation:Stop(mob.Config.feed.animation)
		data.Track = nil
	end

	data.Eating = false
	mob.Model:SetAttribute(FEEDING, nil)
	letGo(mob, data)
end

local function startEating(mob, data)
	local track = mob.Animation:PlayAction(mob.Config.feed.animation)
	if not track then return end

	local visual = mob.Config.feed.visual

	data.Eating = true
	data.Track = track
	data.EatingSince = data.EatingSince or os.clock()
	mob.Model:SetAttribute(FEEDING, true)

	track.Looped = true
	Attacks.Shot(mob, visual)

	data.Markers = {
		track.DidLoop:Connect(function()
			Attacks.Shot(mob, visual)
		end),
		track:GetMarkerReachedSignal(REMOVE_MARKER):Connect(function()
			bite(mob, data)
		end),
		track:GetMarkerReachedSignal(RELEASE_MARKER):Connect(function()
			letGo(mob, data)
		end),
	}
end

local function finish(mob, corpse: Model)
	local finished = mob.Blackboard.Finished or setmetatable({}, { __mode = "k" })
	finished[corpse] = true
	mob.Blackboard.Finished = finished
end

return {
	Enter = function(mob, data)
		data.Food = mob.Blackboard.Food
		Feeding.Join(mob, data.Food)
	end,

	Update = function(mob, data)
		local corpse = Feeding.Corpses():Resolve(data.Food)

		if corpse ~= data.Food then
			Feeding.Leave(mob, data.Food)
			data.Food = corpse
			Feeding.Join(mob, corpse)
		end

		local torso = Feeding.TorsoOf(corpse)

		if not torso then
			stopEating(mob, data)
			return
		end

		local feed = mob.Config.feed
		local point = mob:EngagePoint(torso.Position, feed.distance)
		local now = os.clock()

		if data.Eating then
			mob:Face(torso.Position)

			if not data.Track.IsPlaying or mob:DistanceTo(point) > DRIFT_DISTANCE then
				stopEating(mob, data)
			elseif not CorpseLibrary.Dismember and now - data.EatingSince >= (feed.duration or 0) then
				finish(mob, corpse)
			end

			return
		end

		if mob:DistanceTo(point) <= ARRIVE_DISTANCE then
			data.MovedAt = nil
			mob:Stop()
			mob:Face(torso.Position)
			startEating(mob, data)
			return
		end

		mob:Unface()

		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now
		mob:MoveTo(point, feed.speed or "walk_speed")
	end,

	Exit = function(mob, data)
		stopEating(mob, data)
		Feeding.Leave(mob, data.Food)
		mob:Stop()
		mob:Unface()
	end,
}
