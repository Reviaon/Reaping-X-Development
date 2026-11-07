local Sight = require("../../Senses/Sight")

return function(mob, args)
	if mob.Blackboard.Retreating then return false end

	return Sight.Noticed(mob, mob:Setting(args.detect or "detect_range"))[1] ~= nil
end
