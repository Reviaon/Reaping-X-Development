local Components = {}

Components.FolderName = "@Components"

function Components.Load(host: Instance): { [string]: any }
	local loaded = {}
	local folder = host:FindFirstChild(Components.FolderName)

	if not folder then
		return loaded
	end

	for _, module in folder:GetChildren() do
		if not module:IsA("ModuleScript") then continue end

		local ok, result = pcall(require, module)

		if ok then
			loaded[module.Name] = result
		else
			warn(`[Components] "{module:GetFullName()}" failed to load: {result}`)
		end
	end

	return loaded
end

return Components
