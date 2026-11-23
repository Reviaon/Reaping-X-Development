local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Tempo = require("../../../Combat/Tempo")

local REFRESH = 0.25
local ARRIVE_DISTANCE = 1.5
local UP = Vector3.new(0, 1, 0)

local function planar(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function settingsOf(mob): MobTypes.Tempo
	return mob.Config.tempo
end

local function outward(mob, center: Vector3): Vector3
	local offset = planar(mob.Root.Position - center)

	if offset.Magnitude > 1e-3 then
		return offset.Unit
	end

	return -planar(mob.Root.CFrame.LookVector).Unit
end

local function goal(mob, data, center: Vector3): (Vector3, string | number)
	local tempo = settingsOf(mob)
	local breather: MobTypes.Breather = data.Breather
	local away = outward(mob, center)

	if breather.Kind == "strafe" then
		local radius = planar(mob.Root.Position - center).Magnitude
		local turned = CFrame.fromAxisAngle(UP, math.rad(tempo.strafe.step) * breather.Side):VectorToWorldSpace(away)

		return center + turned * radius, tempo.strafe.speed
	end

	if breather.Kind == "setup" and tempo.setup then
		return center + away * breather.Distance, tempo.setup.speed
	end

	return data.From + away * breather.Distance, tempo.back.speed
end

local function finish(mob, data)
	if data.Done then return end

	data.Done = true
	Tempo.Finish(mob)
	mob:Stop()
end

return {
	Enter = function(mob, data)
		local breather = mob.Blackboard.Breather

		if not breather or not mob.Config.tempo then
			data.Done = true
			Tempo.Finish(mob)
			return
		end

		if breather.Kind ~= "strafe" and breather.Kind ~= "setup" then
			breather.Kind = "back"
		end

		data.Breather = breather
		data.From = mob.Root.Position
		data.Until = os.clock() + breather.Time
	end,

	Update = function(mob, data)
		if data.Done then return end

		local root = mob:TargetRoot()

		if not root or os.clock() >= data.Until then
			finish(mob, data)
			return
		end

		local center = root.Position
		mob:Face(center)

		if data.Breather.Kind == "back" and planar(mob.Root.Position - center).Magnitude >= planar(data.From - center).Magnitude + data.Breather.Distance - ARRIVE_DISTANCE then
			finish(mob, data)
			return
		end

		if data.Breather.Kind == "setup" and planar(mob.Root.Position - center).Magnitude >= data.Breather.Distance - ARRIVE_DISTANCE then
			finish(mob, data)
			return
		end

		local now = os.clock()
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now

		local point, speed = goal(mob, data, center)
		mob:MoveTo(point, speed)
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Exit = function(mob, data)
		if not data.Done then
			Tempo.Finish(mob)
		end

		mob:Stop()
		mob:Unface()
	end,
}
