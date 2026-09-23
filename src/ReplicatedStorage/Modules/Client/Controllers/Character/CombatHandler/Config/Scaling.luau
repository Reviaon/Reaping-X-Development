--@ Resolves one combo entry of a weapon table and retimes it by attack speed
local Defaults = require(script.Parent.Defaults)

local Scaling = {}

function Scaling.ResolveIndexed(value: any, comboIndex: number?): any
	if typeof(value) == "table" then
		return comboIndex and value[comboIndex] or nil
	end

	return value
end

function Scaling.ResolveNumber(value: any, comboIndex: number?, fallback: number): number
	local resolved = Scaling.ResolveIndexed(value, comboIndex)

	--@ resolved ~= resolved catches NaN, which would otherwise stall the attack without erroring
	if typeof(resolved) ~= "number" or resolved ~= resolved then
		return fallback
	end

	return resolved
end

local ResolveNumber = Scaling.ResolveNumber

function Scaling.Impulse(impulseData, parent, speed: number)
	if not impulseData then return nil end

	local scaled = table.clone(impulseData)

	scaled.speed = ResolveNumber(impulseData.speed, nil, Defaults.ImpulseSpeed) * speed
	scaled.duration = ResolveNumber(impulseData.duration, nil, Defaults.ImpulseDuration) / speed
	scaled.falloff = ResolveNumber(impulseData.falloff, nil, Defaults.ImpulseFalloff) / speed
	scaled.rampIn = ResolveNumber(impulseData.rampIn, nil, Defaults.RampIn) / speed

	if scaled.influence == nil and parent then
		scaled.influence = parent.influence
	end

	if scaled.distance == nil and parent then
		scaled.distance = parent.distance
	end

	--@ Studs. Absent, the lunge covers whatever the speed/duration/falloff curve integrates to
	if scaled.distance ~= nil then
		scaled.distance = ResolveNumber(scaled.distance, nil, 0)
	end

	return scaled
end

function Scaling.Knockback(knockbackData, parent, speed: number, impulse)
	local scaled = knockbackData and table.clone(knockbackData) or {}

	if parent then
		if scaled.speed == nil then scaled.speed = parent.speed end
		if scaled.duration == nil then scaled.duration = parent.duration end
		if scaled.falloff == nil then scaled.falloff = parent.falloff end
		if scaled.priority == nil then scaled.priority = parent.priority end
		if scaled.enabled == nil then scaled.enabled = parent.enabled end
		if scaled.face == nil then scaled.face = parent.face end
		if scaled.faceResponsiveness == nil then scaled.faceResponsiveness = parent.faceResponsiveness end
		if scaled.distance == nil then scaled.distance = parent.distance end
	end

	if scaled.speed ~= nil then
		scaled.speed = ResolveNumber(scaled.speed, nil, Defaults.ImpulseSpeed) * speed
	end
	if scaled.duration ~= nil then
		scaled.duration = ResolveNumber(scaled.duration, nil, Defaults.ImpulseDuration) / speed
	end
	if scaled.falloff ~= nil then
		scaled.falloff = ResolveNumber(scaled.falloff, nil, Defaults.ImpulseFalloff) / speed
	end

	--@ A knockback that names nothing of its own takes the attacker's lunge curve wholesale, so the
	--@ shove and the step that delivered it cover the same studs by construction
	if impulse then
		if scaled.speed == nil then scaled.speed = impulse.speed end
		if scaled.duration == nil then scaled.duration = impulse.duration end
		if scaled.falloff == nil then scaled.falloff = impulse.falloff end
		if scaled.rampIn == nil then scaled.rampIn = impulse.rampIn end
		if scaled.distance == nil then scaled.distance = impulse.distance end
	end

	scaled.speed = scaled.speed or Defaults.ImpulseSpeed
	scaled.duration = scaled.duration or Defaults.ImpulseDuration
	scaled.falloff = scaled.falloff or Defaults.ImpulseFalloff
	scaled.priority = scaled.priority or 1
	scaled.rampIn = ResolveNumber(scaled.rampIn, nil, Defaults.RampIn)

	if scaled.face == nil then
		scaled.face = Defaults.KnockbackFace
	end

	scaled.faceResponsiveness = ResolveNumber(scaled.faceResponsiveness, nil, Defaults.KnockbackFaceResponsiveness)

	if scaled.distance ~= nil then
		scaled.distance = ResolveNumber(scaled.distance, nil, 0)
	end

	return scaled
end

function Scaling.Hitbox(hitboxData, parent, speed: number)
	local scaled = hitboxData and table.clone(hitboxData) or {}

	if parent then
		if scaled.shape == nil then scaled.shape = parent.shape end
		if scaled.size == nil then scaled.size = parent.size end
		if scaled.offset == nil then scaled.offset = parent.offset end
		if scaled.duration == nil then scaled.duration = parent.duration end
		if scaled.max_targets == nil then scaled.max_targets = parent.max_targets end
		if scaled.max_hits_per_target == nil then scaled.max_hits_per_target = parent.max_hits_per_target end
		if scaled.enabled == nil then scaled.enabled = parent.enabled end
		if scaled.effect == nil then scaled.effect = parent.effect end
	end

	local shape = scaled.shape or "Box"
	if not Defaults.HitboxShapes[shape] then
		warn(`[CombatConfig] Hitbox shape "{tostring(shape)}" is not one of Box/Sphere/Cylinder - using Box.`)
		shape = "Box"
	end

	scaled.shape = shape
	scaled.size = typeof(scaled.size) == "Vector3" and scaled.size or Defaults.HitboxSize
	scaled.offset = typeof(scaled.offset) == "Vector3" and scaled.offset or Defaults.HitboxOffset
	scaled.max_targets = ResolveNumber(scaled.max_targets, nil, -1)
	scaled.max_hits_per_target = ResolveNumber(scaled.max_hits_per_target, nil, 1)
	scaled.duration = ResolveNumber(scaled.duration, nil, Defaults.HitboxDuration) / speed

	return scaled
end

function Scaling.Finisher(data)
	if data == false then return nil end
	if typeof(data) == "table" and data.enabled == false then return nil end

	local finisher = {}

	for key, fallback in Defaults.Finisher do
		finisher[key] = ResolveNumber(typeof(data) == "table" and data[key] or nil, nil, fallback)
	end

	return finisher
end

return Scaling
