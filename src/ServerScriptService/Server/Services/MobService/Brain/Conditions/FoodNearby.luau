local Feeding = require("../../Feeding")

return function(mob)
	if not mob.Config.feed then return false end

	local food = Feeding.Find(mob)
	mob.Blackboard.Food = food

	return food ~= nil
end
