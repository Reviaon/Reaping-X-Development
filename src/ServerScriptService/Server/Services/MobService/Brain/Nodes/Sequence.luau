local Status = require("../Status")

local Sequence = {}
Sequence.__index = Sequence

function Sequence.new(children)
	return setmetatable({ Children = children }, Sequence)
end

function Sequence:Tick(mob, dt)
	for _, child in self.Children do
		local result = child:Tick(mob, dt)

		if result ~= Status.Success then
			return result
		end
	end

	return Status.Success
end

return Sequence
