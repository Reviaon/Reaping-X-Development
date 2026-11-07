local Path = require("../../Path")

local Section = {}

function Section.Brief(mob): string?
	if not mob.Config.path then return nil end

	local state = Path.State(mob)
	local unreachable = Path.Unreachable(mob, mob.Target) ~= nil

	if unreachable then
		return if state == "direct" then "unreachable" else `{state}, unreachable`
	end

	return if state == "direct" then nil else state
end

function Section.Report(mob): { string }
	return Path.Describe(mob)
end

return Section
