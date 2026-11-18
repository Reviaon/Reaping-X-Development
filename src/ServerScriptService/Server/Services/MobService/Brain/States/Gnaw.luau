local Jloader = require("@game/ReplicatedStorage/JLoader")
local Attacks = require("../../Combat/Attacks")

local REFRESH = 0.25
local ARRIVE_DISTANCE = 2
local DRIFT_DISTANCE = 4
local FEEDING = "IsFeeding"

local function bodyOf(target: Model?): BasePart?
	local body = target and (target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	return if body and body:IsA("BasePart") then body else nil
end

local function stopChewing(mob, data)
	for _, connection in data.Markers or {} do
		connection:Disconnect()
	end

	data.Markers = nil

	if data.Track then
		mob.Animation:Stop(mob.Config.gnaw.animation)
		data.Track = nil
	end

	data.Chewing = false
	mob.Model:SetAttribute(FEEDING, nil)
end

local function bite(mob, data)
	local target = data.Target
	if not target or not Jloader.GlobalFunctions.RagdollService.IsRagdolled(target) then return end

	Jloader.GetService("CombatService"):SceneStrike(target, { Damage = mob.Config.gnaw.damage })
end

local function startChewing(mob, data)
	local gnaw = mob.Config.gnaw
	local track = mob.Animation:PlayAction(gnaw.animation)
	if not track then return end

	data.Chewing = true
	data.Track = track
	mob.Model:SetAttribute(FEEDING, true)

	track.Looped = true
	Attacks.Shot(mob, gnaw.visual)

	data.Markers = {
		track.DidLoop:Connect(function()
			Attacks.Shot(mob, gnaw.visual)
		end),
		track:GetMarkerReachedSignal(gnaw.marker):Connect(function()
			bite(mob, data)
		end),
	}
end

return {
	Enter = function(mob, data)
		data.Target = mob:GetTarget()
		mob.Blackboard.Gnawing = data.Target
		mob.Blackboard.Scatter = nil
	end,

	Update = function(mob, data)
		local body = bodyOf(data.Target)

		if not body or data.Target ~= mob:GetTarget() then
			stopChewing(mob, data)
			return
		end

		local gnaw = mob.Config.gnaw
		local point = mob:EngagePoint(body.Position, gnaw.distance)

		if data.Chewing then
			mob:Face(body.Position)

			if not data.Track.IsPlaying or mob:DistanceTo(point) > DRIFT_DISTANCE then
				stopChewing(mob, data)
			end

			return
		end

		if mob:DistanceTo(point) <= ARRIVE_DISTANCE then
			data.MovedAt = nil
			mob:Stop()
			mob:Face(body.Position)
			startChewing(mob, data)
			return
		end

		mob:Unface()

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now
		mob:MoveTo(point, gnaw.speed)
	end,

	Exit = function(mob, data)
		stopChewing(mob, data)
		mob:Stop()
		mob:Unface()

		local target = data.Target
		local blackboard = mob.Blackboard

		if blackboard.Gnawing == target then
			blackboard.Gnawing = nil
		end

		local alive = target and target.Parent and mob.Services.StatusService:IsAlive(target)

		if alive and not Jloader.GlobalFunctions.RagdollService.IsRagdolled(target) then
			blackboard.Scatter = true
		end
	end,
}
