local Path = require("../../Path")

return function(mob)
	return Path.Unreachable(mob, mob:GetTarget()) ~= nil
end
