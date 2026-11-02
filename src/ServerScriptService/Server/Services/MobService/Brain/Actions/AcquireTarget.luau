local Perception = require("../../Perception")

local function within(mob, target: Model, range: number): boolean
	local root = Perception.RootOf(target)
	return root ~= nil and (root.Position - mob.Root.Position).Magnitude <= range
end

local function adopt(mob, target: Model): boolean
	mob:SetTarget(target)

	if mob.Team then
		mob.Team:Share(target)
	end

	return true
end

return function(mob, args)
	local lose = mob:Setting(args.lose or "lose_range")
	local team = mob.Team

	local provoker = mob:Provoker()
	if provoker then
		return adopt(mob, provoker)
	end

	local shared = team and team:GetTarget()

	if shared then
		if within(mob, shared, lose) or team:Holds(shared, lose, mob) then
			mob:SetTarget(shared)
			return true
		end

		team:Drop(shared)
	end

	local current = mob:GetTarget()

	if current and within(mob, current, lose) then
		return adopt(mob, current)
	end

	local target = Perception.NearestPlayer(mob.Root.Position, mob:Setting(args.detect or "detect_range"))

	if not target then
		mob:SetTarget(nil)
		return false
	end

	return adopt(mob, target)
end
