--[[@
	**Registry**: modules found by name under one folder, required the first time they are asked for
	- **Category folders:** a `Folder` inside it only groups; its modules are found by the same bare name, however deep, so moving a module between categories changes no code
	  - `Brain/States` and `Brain/Conditions` group by who uses them: `Shared` (more than one tree, or asked for by a service), else the folder named after the one tree that does (`Hunter`, `Prey`, `Alarm`)
	- **Folder modules** (an `init` with subscripts, like `States/Alarm/Flit`) are one entry; their children are never looked into
	- **Names are unique** across the categories; two modules sharing one is an error naming both
]]
local Registry = {}

local function gather(folder: Instance, label: string, found: { [string]: ModuleScript })
	for _, child in folder:GetChildren() do
		if child:IsA("Folder") then
			gather(child, label, found)
		elseif child:IsA("ModuleScript") then
			local other = found[child.Name]

			if other then
				error(`[MobService] Two {label}s are named "{child.Name}": {other:GetFullName()} and {child:GetFullName()}.`)
			end

			found[child.Name] = child
		end
	end
end

function Registry.new(folder: Instance, label: string)
	local modules: { [string]: ModuleScript }? = nil

	return setmetatable({}, {
		__index = function(cache, name)
			if not modules then
				local found = {}

				gather(folder, label, found)
				modules = found
			end

			local module = (modules :: { [string]: ModuleScript })[name]

			if not module then
				error(`[MobService] There is no {label} named "{tostring(name)}" under {folder:GetFullName()}.`, 2)
			end

			local loaded = require(module)
			rawset(cache, name, loaded)

			return loaded
		end,
	})
end

return Registry
