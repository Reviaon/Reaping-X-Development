local Tree = require("../Tree")

local Action = {}
Action.__index = Action

function Action.new(name: string, args)
	return setmetatable({ Name = name, Run = Tree.Actions[name], Args = args or {} }, Action)
end

function Action:Tick(mob, dt)
	return Tree.FromResult(self.Run(mob, self.Args, dt))
end

return Action
