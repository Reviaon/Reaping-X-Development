local Group = {}

function Group.Class(parts: { any }, label: string)
	local class = { Parts = parts, Label = label }
	class.__index = class

	for _, part in parts do
		for name, method in part.Methods do
			assert(class[name] == nil, `[Team] two {label} parts define {name}`)
			class[name] = method
		end
	end

	function class:Describe(mob): { string }
		local members = 0

		for _ in self.Members do
			members += 1
		end

		local lines = { `{label} of {members}` }

		for _, part in parts do
			if part.Describe then
				for _, line in part.Describe(self, mob) do
					table.insert(lines, line)
				end
			end
		end

		return lines
	end

	return class
end

function Group.Registry(class)
	local groups = {}
	local registry = {}

	function registry.Get(key: any)
		return groups[key]
	end

	function registry.Join(mob, key: any)
		if key == nil then return nil end

		local group = groups[key]

		if not group then
			group = { Key = key, Members = {} }

			for _, part in class.Parts do
				for field, value in part.State() do
					group[field] = value
				end
			end

			setmetatable(group, class)
			groups[key] = group
		end

		group.Members[mob] = true

		return group
	end

	function registry.Leave(group, mob)
		group.Members[mob] = nil

		for _, part in class.Parts do
			if part.Forget then
				part.Forget(group, mob)
			end
		end

		if next(group.Members) == nil and groups[group.Key] == group then
			groups[group.Key] = nil
		end
	end

	return registry
end

return Group
