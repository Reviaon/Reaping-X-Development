local Attacks = require("../../Combat/Attacks")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local FLAT = Vector3.new(1, 0, 1)
local SLACK = 0.5

local random = Random.new()

local function settingsOf(mob): MobTypes.Lurk
	return mob.Config.lurk
end

local function bodyOf(mob): Vector3?
	local target = mob:GetTarget()
	local body = target and (target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	return if body and body:IsA("BasePart") then body.Position else nil
end

local function nextNip(lurk: MobTypes.Lurk, first: boolean?): number
	local range = if first then lurk.nip.first else lurk.nip.every
	return os.clock() + random:NextNumber(range[1], range[2])
end

local function outwardFrom(mob, body: Vector3): (Vector3, number)
	local offset = (mob.Root.Position - body) * FLAT

	if offset.Magnitude > 1e-3 then
		return offset.Unit, offset.Magnitude
	end

	local back = -mob.Root.CFrame.LookVector * FLAT
	return if back.Magnitude > 1e-3 then back.Unit else Vector3.zAxis, 0
end

local function bite(mob, biting, lurk: MobTypes.Lurk, now: number)
	local settings = lurk.nip

	biting.Phase = "Bite"
	biting.At = now

	mob:Stop()

	if settings.animation then
		mob.Animation:PlayAction(mob.Animation:Variant(settings.animation))
	end

	Attacks.Shot(mob, settings.visual)
end

local function nip(mob, data, lurk: MobTypes.Lurk, body: Vector3, outward: Vector3, distance: number, now: number)
	local settings = lurk.nip
	local biting = data.Nip

	if biting.Phase == "In" then
		if distance <= settings.reach + SLACK or now - biting.At >= settings.approach then
			bite(mob, biting, lurk, now)
		else
			mob:MoveTo(body + outward * settings.reach, settings.speed)
		end

		return
	end

	if not biting.Struck and now - biting.At >= settings.windup then
		biting.Struck = true
		Attacks.Nip(mob, mob:GetTarget(), settings)
		mob:MoveTo(body + outward * lurk.band[2], "walk_speed")
	end

	if now - biting.At >= settings.windup + settings.recovery then
		data.Nip = nil
		data.NipAt = nextNip(lurk)
	end
end

return {
	Locked = function(_, data)
		return data.Nip ~= nil
	end,

	Enter = function(mob, data)
		data.NipAt = nextNip(settingsOf(mob), true)
	end,

	Update = function(mob, data)
		local lurk = settingsOf(mob)
		local body = bodyOf(mob)

		if not body then
			data.Nip = nil
			return
		end

		local now = os.clock()
		local outward, distance = outwardFrom(mob, body)

		mob:Face(body)

		if data.Nip then
			nip(mob, data, lurk, body, outward, distance, now)
			return
		end

		if now >= data.NipAt then
			data.Nip = { Phase = "In", At = now, Struck = false }
			mob:MoveTo(body + outward * lurk.nip.reach, lurk.nip.speed)
			mob:Burst(lurk.nip.speed)
			return
		end

		if distance < lurk.band[1] or distance > lurk.band[2] then
			mob:MoveTo(body + outward * (lurk.band[1] + lurk.band[2]) / 2, "walk_speed")
		else
			mob:Stop()
		end
	end,

	Exit = function(mob)
		mob:Unface()
		mob:Stop()
	end,
}
