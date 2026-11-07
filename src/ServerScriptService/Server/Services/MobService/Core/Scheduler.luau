local Perception = require("../Senses/Perception")

local Scheduler = {}

function Scheduler.Tier(tiers, distance: number)
	for _, tier in tiers do
		if distance <= tier.range then
			return tier
		end
	end

	return tiers[#tiers]
end

local function guarded(mob, method, dt: number)
	local ran, problem = xpcall(method, debug.traceback, mob, dt)
	if ran then return end

	warn(`[MobService] {mob.Name} errored and was removed:\n{problem}`)
	mob:Destroy()
end

function Scheduler.Step(mobs, now: number, frameDt: number, settings): (number, number)
	local count = 0

	for mob in mobs do
		count += 1

		if not mob.Dead and (not mob.Tier or mob.Tier.smooth ~= false) then
			guarded(mob, mob.Step, frameDt)
		end
	end

	local budget = settings.MaxThinksPerFrame
	local thinks = 0

	for mob in mobs do
		if budget <= 0 then break end
		if mob.Dead or now < mob.NextThinkAt then continue end

		budget -= 1
		thinks += 1

		local tier = Scheduler.Tier(settings.Tiers, Perception.NearestPlayerDistance(mob.Root.Position))
		local dt = now - mob.LastThinkAt

		mob.Tier = tier
		mob.LastThinkAt = now
		mob.NextThinkAt = now + tier.interval
		mob.Animation:SetCulled(not tier.animate)

		if tier.smooth == false then
			guarded(mob, mob.Step, dt)
		end

		guarded(mob, mob.Think, dt)
	end

	return thinks, count
end

return Scheduler
