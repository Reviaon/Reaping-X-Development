local Status = require("../Status")

local Cooldown = {}
Cooldown.__index = Cooldown

function Cooldown.new(seconds: number, child)
	return setmetatable({ Seconds = seconds, Child = child }, Cooldown)
end

function Cooldown:Tick(mob, dt)
	local now = os.clock()
	local readyAt = mob.Memory[self]

	if readyAt and now < readyAt then
		return Status.Failure
	end

	local result = self.Child:Tick(mob, dt)

	if result == Status.Success then
		mob.Memory[self] = now + self.Seconds
	end

	return result
end

return Cooldown
