local Path = require("../../Path")

local Reach = {}

local function heldAbove(mob, entry, root: BasePart, rule, now: number): boolean
	if typeof(rule.height) ~= "number" or root.Position.Y - mob.Root.Position.Y <= rule.height then
		entry.AboveSince = nil
		return false
	end

	entry.AboveSince = entry.AboveSince or now

	return now - entry.AboveSince >= (rule.after or 0)
end

function Reach.Scale(mob, target: Model, entry, root: BasePart, settings, now: number): number
	local rule = settings.unreachable
	if typeof(rule) ~= "table" then return 1 end

	local above = heldAbove(mob, entry, root, rule, now)

	return if above or Path.Unreachable(mob, target) then rule.scale else 1
end

return Reach
