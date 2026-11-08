local Healing = {}

local function calm(mob, settings, now: number): boolean
	local blackboard = mob.Blackboard

	if mob:GetTarget() or mob:Provoker() then return false end
	if blackboard.Returning or blackboard.Retreating or blackboard.Search then return false end
	if mob.HurtAt and now - mob.HurtAt < settings.delay then return false end

	return mob:HomeDistance() <= mob:Setting(settings.range or "wander_radius")
end

function Healing.Step(mob, dt: number)
	local settings = mob.Config.healing
	local humanoid = mob.Humanoid

	mob.Healing = settings and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and calm(mob, settings, os.clock()) or false
	if not mob.Healing then return end

	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * settings.rate * dt)

	if humanoid.Health >= humanoid.MaxHealth then
		mob.Blackboard.Rallied = nil
	end
end

return Healing
