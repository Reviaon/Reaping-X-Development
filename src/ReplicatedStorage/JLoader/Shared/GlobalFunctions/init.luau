local sharedModule = {}

setmetatable(sharedModule, {
	__index = function(tbl, index)
		if typeof(index) == "string" then
			local module

			--@ Check direct ModuleScript children first
			module = script:FindFirstChild(index)
			if module and not module:IsA("ModuleScript") then
				module = nil
			end

			--@ Search through all folders inside the script
			if not module then
				for _, folder in ipairs(script:GetChildren()) do
					if folder:IsA("Folder") then
						module = folder:FindFirstChild(index)
						if module then
							break
						end
					end
				end
			end

			--@ If module is found, require it and cache it in sharedModule
			if module then
				rawset(sharedModule, index, require(module))
			end

			return rawget(sharedModule, index)
		end
	end
})

return sharedModule