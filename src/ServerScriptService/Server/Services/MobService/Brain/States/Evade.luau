local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Obstacles = require("../../World/Obstacles")
local Predators = require("../../Senses/Predators")

local function settingsOf(mob): MobTypes.Evade
	return mob.Config.evade
end

local function reach(origin: Vector3, direction: Vector3, distance: number): number
	local hit = workspace:Raycast(origin, direction * distance, Obstacles.Params())
	return if hit then hit.Distance else distance
end

local function heading(mob, away: Vector3, settings: MobTypes.Evade): Vector3
	local origin = mob.Root.Position + Vector3.new(0, mob.Root.Size.Y, 0)
	local best, farthest = away, -1

	for _, degrees in settings.fan do
		local direction = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(away)
		local clear = reach(origin, direction, settings.distance)

		if clear >= settings.distance then return direction end

		if clear > farthest then
			best, farthest = direction, clear
		end
	end

	return best
end

return {
	Enter = function(mob, data)
		data.MovedAt = nil
		mob:SetTarget(nil)
		mob:Unface()
	end,

	Update = function(mob, data)
		local settings = settingsOf(mob)
		local now = os.clock()

		mob.Blackboard.EvadedAt = now

		if data.MovedAt and now - data.MovedAt < settings.refresh then return end

		local away = Predators.Away(mob, mob.Blackboard.Predators or {})
		if not away then return end

		data.MovedAt = now
		mob:MoveTo(mob.Root.Position + heading(mob, away, settings) * settings.distance, settings.speed)
	end,

	Exit = function(mob)
		mob:Stop()
	end,
}
