local Tree = require("../Tree")

local Condition = {}
Condition.__index = Condition

function Condition.new(name: string, args)
	return setmetatable({ Name = name, Check = Tree.Conditions[name], Args = args or {} }, Condition)
end

function Condition:Tick(mob)
	return if self.Check(mob, self.Args) then Tree.Status.Success else Tree.Status.Failure
end

return Condition
