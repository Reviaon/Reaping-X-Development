local Perception = require("../../Perception")

local function within(mob, target: Model, range: number): boolean
	local root = Perception.RootOf(target)
	return root ~= nil and (root.Position - mob.Root.Position).Magnitude <= range
end

local function packTarget(mob, team, lose: number, detect: number): Model?
	for _, player in Perception.PlayersNear(mob.Root.Position, detect) do
		team:Share(player)
	end

	local provoker = mob:Provoker()

	if provoker then
		team:Share(provoker)
		return provoker
	end

	return team:Assign(mob, lose)
end

local function soloTarget(mob, lose: number, detect: number): Model?
	local provoker = mob:Provoker()
	if provoker then return provoker end

	local current = mob:GetTarget()
	if current and within(mob, current, lose) then return current end

	return Perception.NearestPlayer(mob.Root.Position, detect)
end

return function(mob, args)
	local lose = mob:Setting(args.lose or "lose_range")
	local detect = mob:Setting(args.detect or "detect_range")
	local team = mob.Team
	local target = if team then packTarget(mob, team, lose, detect) else soloTarget(mob, lose, detect)

	mob:SetTarget(target)

	return target ~= nil
end
