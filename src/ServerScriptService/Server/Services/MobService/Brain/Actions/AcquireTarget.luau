local Perception = require("../../Senses/Perception")
local Sight = require("../../Senses/Sight")

local function keeps(mob, target: Model?, range: number): boolean
	local root = Perception.RootOf(target)
	if not root or (root.Position - mob.Root.Position).Magnitude > range then return false end

	return Sight.Knows(mob, target)
end

local function packTarget(mob, team, lose: number, detect: number): Model?
	local noticed = Sight.Noticed(mob, detect)

	for _, player in noticed do
		team:Share(player)
	end

	local provoker = mob:Provoker()

	if provoker then
		team:Share(provoker)
		team:Engage(mob, true)
		return provoker
	end

	local current = mob:GetTarget()
	team:Engage(mob, #noticed > 0 or keeps(mob, current, lose))

	return team:Assign(mob, lose)
end

local function soloTarget(mob, lose: number, detect: number): Model?
	local provoker = mob:Provoker()
	if provoker then return provoker end

	local current = mob:GetTarget()
	if keeps(mob, current, lose) then return current end

	return Sight.Noticed(mob, detect)[1]
end

local function search(mob, lost: Model)
	local settings = mob.Config.search
	if not settings or not Perception.IsValidTarget(lost) then return end

	local _, position = Sight.LastSeen(mob, lost)
	if not position then return end

	mob.Blackboard.Search = { Target = lost, Position = position, Until = os.clock() + settings.time }
end

return function(mob, args)
	local lose = mob:Setting(args.lose or "lose_range")
	local detect = mob:Setting(args.detect or "detect_range")
	local team = mob.Team
	local previous = mob.Target
	local target = if team then packTarget(mob, team, lose, detect) else soloTarget(mob, lose, detect)
	local blackboard = mob.Blackboard

	mob:SetTarget(target)

	if target then
		blackboard.Search = nil

		if blackboard.Returning and not blackboard.Retreating then
			blackboard.Returning = false
		end
	elseif previous then
		search(mob, previous)
	end

	return target ~= nil
end
