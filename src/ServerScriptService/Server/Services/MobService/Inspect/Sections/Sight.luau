local Sight = require("../../Senses/Sight")

local Section = {}

function Section.Brief(mob): string?
	local target = mob.Target
	if not target or not mob.Config.sight or mob.Dead then return nil end
	if Sight.Sees(mob, target) then return nil end

	return if Sight.Hears(mob, target) then "heard" else "tracking unseen"
end

function Section.Report(mob): { string }
	return Sight.Describe(mob)
end

return Section
