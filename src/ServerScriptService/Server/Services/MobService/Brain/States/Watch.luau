local Perception = require("../../Senses/Perception")

local function nearest(mob): BasePart?
	local best, bestDistance = nil, math.huge

	for _, predator in mob.Blackboard.Predators or {} do
		local root = Perception.RootOf(predator)
		local distance = if root then (root.Position - mob.Root.Position).Magnitude else math.huge

		if distance < bestDistance then
			best, bestDistance = root, distance
		end
	end

	return best
end

return {
	Enter = function(mob)
		mob:Stop()
	end,

	Update = function(mob)
		mob.Blackboard.EvadedAt = os.clock()

		local root = nearest(mob)

		if root then
			mob:Face(root.Position)
		end
	end,

	Exit = function(mob)
		mob:Unface()
	end,
}
