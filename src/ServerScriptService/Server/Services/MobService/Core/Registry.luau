local Registry = {}

function Registry.new(folder: Instance, label: string)
	return setmetatable({}, {
		__index = function(cache, name)
			local module = folder:FindFirstChild(name)

			if not module or not module:IsA("ModuleScript") then
				error(`[MobService] There is no {label} named "{tostring(name)}" under {folder:GetFullName()}.`, 2)
			end

			local loaded = require(module)
			rawset(cache, name, loaded)

			return loaded
		end,
	})
end

return Registry
