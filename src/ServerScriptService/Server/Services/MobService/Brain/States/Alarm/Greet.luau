--[[@
	**Greet**: a passive bird's hello to the player it is visiting (`greet`)
	- **Approach:** it walks up to `greet.distance` studs from them
	- **Bow:** it faces them, plays `greet.startup`, then holds `greet.bow` for `greet.hold` seconds
	- **Answer:** while it bows, `greet.answer` puts up an interaction (`Combat/Prompt`); the first player beside it to take it turns to the bird and plays their own gesture (`Combat/Gesture`), stood `answer.spacing` studs in front of it so the two poses meet, and the bird squares up to them and holds its bow until that gesture ends
	- **Then** the visit moves on to its `follow` stage; anything higher in the tree (a hit, a startle) cuts it short
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Gesture = require("../../../Combat/Gesture")
local Perception = require("../../../Senses/Perception")
local Prompt = require("../../../Combat/Prompt")

local FALLBACK_LENGTH = 1
local REFRESH = 0.2
local APPROACH_TIMEOUT = 6
local ARRIVE_SLACK = 2
local FLAT = Vector3.new(1, 0, 1)

local random = Random.new()

local function settingsOf(mob): MobTypes.Greet
	return mob.Config.greet
end

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2] or range[1])
end

local function standPoint(mob, root: BasePart, distance: number): Vector3
	local offset = (mob.Root.Position - root.Position) * FLAT
	local away = if offset.Magnitude > 1e-3 then offset.Unit else (root.CFrame.LookVector * FLAT).Unit

	return root.Position + away * distance
end

local function advance(mob, greet: MobTypes.Greet)
	local visit = mob.Blackboard.Visit
	if not visit or visit.Stage ~= "greet" then return end

	visit.Stage = "follow"
	visit.StageUntil = os.clock() + roll(greet.follow)
	visit.Flying = random:NextNumber() < greet.fly_chance
end

local function invite(mob, data, answer: MobTypes.Answer)
	Prompt.Offer(mob, answer, function(character)
		if data.Phase ~= "bow" or data.Done or data.Guest then return end
		local facing = Gesture.Play(mob, character, answer)
		if not facing then return end

		Prompt.Withdraw(mob)

		data.Guest = character
		data.FaceAt = facing
		data.At = os.clock()
		data.Hold = answer.duration
	end)
end

return {
	Done = function(_, data)
		return data.Done == true
	end,

	Enter = function(mob, data)
		data.Phase = "approach"
		mob:Unface()
	end,

	Update = function(mob, data, _, elapsed)
		if data.Done then return end

		local greet = settingsOf(mob)
		local root = Perception.RootOf(mob.Blackboard.Companion)
		local now = os.clock()

		if not root then
			data.Done = true
			return
		end

		if data.Phase == "approach" then
			local distance = ((root.Position - mob.Root.Position) * FLAT).Magnitude

			if distance <= greet.distance + ARRIVE_SLACK or elapsed >= APPROACH_TIMEOUT then
				mob:Stop()
				mob:Face(root.Position)
				data.Phase = "startup"
				data.At = now
				data.Track = if greet.startup then mob.Animation:PlayAction(greet.startup) else nil
				return
			end

			if data.MovedAt and now - data.MovedAt < REFRESH then return end

			data.MovedAt = now
			mob:MoveTo(standPoint(mob, root, greet.distance), "walk_speed")
			return
		end

		mob:Face(data.FaceAt or root.Position)

		if data.Phase == "startup" then
			local track = data.Track
			local length = if track and track.Length > 0 then track.Length elseif greet.startup then FALLBACK_LENGTH else 0

			if now - data.At < length then return end

			data.Phase = "bow"
			data.At = now
			data.Hold = roll(greet.hold)

			if greet.bow then
				mob.Animation:PlayLoop(greet.bow)
			end

			if greet.answer then
				invite(mob, data, greet.answer)
			end
		elseif now - data.At >= data.Hold then
			data.Done = true
			advance(mob, greet)
		end
	end,

	Exit = function(mob, data)
		local greet = settingsOf(mob)

		mob:Unface()
		mob:Stop()
		Prompt.Withdraw(mob)

		if greet.bow then
			mob.Animation:Stop(greet.bow)
		end

		if data.Phase == "startup" and greet.startup then
			mob.Animation:Stop(greet.startup)
		end
	end,
}
