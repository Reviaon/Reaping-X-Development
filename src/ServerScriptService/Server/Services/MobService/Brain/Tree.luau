local Registry = require("../Registry")
local Status = require("./Status")

local Tree = {}

Tree.Status = Status

Tree.Nodes = Registry.new(script.Parent.Nodes, "behavior node")
Tree.Conditions = Registry.new(script.Parent.Conditions, "condition")
Tree.Actions = Registry.new(script.Parent.Actions, "action")
Tree.States = Registry.new(script.Parent.States, "state")

Tree.Builder = setmetatable({}, {
	__index = function(_, name)
		local node = Tree.Nodes[name]

		return function(...)
			return node.new(...)
		end
	end,
})

local built = {}

function Tree.Get(trees: Instance, name: string)
	local root = built[name]
	if root then return root end

	local definition = trees:FindFirstChild(name)

	if not definition or not definition:IsA("ModuleScript") then
		error(`[MobService] There is no tree named "{tostring(name)}" under {trees:GetFullName()}.`, 2)
	end

	root = require(definition)(Tree.Builder)
	built[name] = root

	return root
end

function Tree.Tick(node, mob, dt: number): string
	return node:Tick(mob, dt)
end

function Tree.FromResult(result: any): string
	if result == true then return Status.Success end
	if result == false or result == nil then return Status.Failure end

	return result
end

return Tree
