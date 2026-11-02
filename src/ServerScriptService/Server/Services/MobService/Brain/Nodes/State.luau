local Tree = require("../Tree")

local State = {}
State.__index = State

function State.new(name: string, options)
	options = options or {}

	assert(Tree.States[name], name)

	return setmetatable({ Name = name, Args = options.args, Force = options.force == true }, State)
end

function State:Tick(mob)
	mob.Machine:Request(self.Name, self.Args, self.Force)

	return Tree.Status.Running
end

return State
