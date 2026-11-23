local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local random = Random.new()

local function roll(range: { number }): number
	return random:NextNumber(range[1], range[2])
end

return function(mob)
	local swoop: MobTypes.Swoop? = mob.Config.swoop or nil
	if not swoop or not mob:GetTarget() then return false end

	local board = mob.Blackboard
	local now = os.clock()

	if not board.SwoopAt then
		board.SwoopAt = now + roll(swoop.first)
		return false
	end

	if board.SwoopFrom and (board.LastAttackAt or 0) >= board.SwoopFrom then
		board.SwoopFrom = nil
		board.SwoopAt = now + roll(swoop.every)
		return false
	end

	if now < board.SwoopAt then return false end

	board.SwoopFrom = board.SwoopFrom or now
	return true
end
