local Status = require("../Status")

local Selector = {}
Selector.__index = Selector

function Selector.new(children)
	return setmetatable({ Children = children }, Selector)
end

function Selector:Tick(mob, dt)
	for _, child in self.Children do
		local result = child:Tick(mob, dt)

		if result ~= Status.Failure then
			return result
		end
	end

	return Status.Failure
end

return Selector
