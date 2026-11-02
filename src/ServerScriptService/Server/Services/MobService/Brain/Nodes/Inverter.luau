local Status = require("../Status")

local Inverter = {}
Inverter.__index = Inverter

function Inverter.new(child)
	return setmetatable({ Child = child }, Inverter)
end

function Inverter:Tick(mob, dt)
	local result = self.Child:Tick(mob, dt)

	if result == Status.Success then return Status.Failure end
	if result == Status.Failure then return Status.Success end

	return result
end

return Inverter
