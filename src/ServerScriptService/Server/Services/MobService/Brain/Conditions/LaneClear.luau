local Path = require("../../Path")

return function(mob)
	local root = mob:TargetRoot()
	return root ~= nil and Path.LaneClear(mob, root.Position)
end
