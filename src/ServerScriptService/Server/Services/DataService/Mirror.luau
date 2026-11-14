--[[@
	**Mirror**: replicates a profile's data to the client as a tree of Value instances
	- **Shape:** a table becomes a Folder, and every other value a NumberValue, StringValue or BoolValue named by its key
	  - Array keys are named by their index and read back as numbers
	  - Types a profile can't save are skipped with a warning
	- **Writes flow back:** the server edits the Values and the profile follows
	  - Setting `.Value` writes that key
	  - Parenting a new Value or Folder under a mirrored Folder adds its subtree
	  - Removing one deletes the key
	  - Writing the profile table directly doesn't replicate, so go through the Values
	- **Built whole before parenting**, so a client never sees a half-built tree
]]
local Config = require("./Config")
local Types = require("./Types")

type Data = Types.Data

local Mirror = {}

local function keyOf(name: string): string | number
	return tonumber(name) or name
end

local function read(instance: Instance): any
	if instance:IsA("Folder") then
		local data: Data = {}

		for _, child in instance:GetChildren() do
			data[keyOf(child.Name)] = read(child)
		end

		return data
	end

	if instance:IsA("ValueBase") then
		return (instance :: any).Value
	end

	return nil
end

local watch: (Instance, Data, string | number) -> ()

local function watchFolder(folder: Folder, data: Data)
	folder.ChildAdded:Connect(function(child: Instance)
		local key = keyOf(child.Name)

		data[key] = read(child)
		watch(child, data, key)
	end)

	folder.ChildRemoved:Connect(function(child: Instance)
		data[keyOf(child.Name)] = nil
	end)

	for _, child in folder:GetChildren() do
		watch(child, data, keyOf(child.Name))
	end
end

watch = function(instance: Instance, owner: Data, key: string | number)
	if instance:IsA("Folder") then
		local data = owner[key]

		if typeof(data) == "table" then
			watchFolder(instance, data)
		end

		return
	end

	if instance:IsA("ValueBase") then
		(instance :: any).Changed:Connect(function(value: any)
			owner[key] = value
		end)
	end
end

local function build(name: string, value: any): Instance?
	local class = Config.Classes[typeof(value)]

	if not class then
		warn(`[DataService] "{name}" holds a {typeof(value)}, which no Value class mirrors; it isn't replicated`)
		return nil
	end

	local instance = Instance.new(class)
	instance.Name = name

	if instance:IsA("Folder") then
		for key, child in value :: Data do
			local built = build(tostring(key), child)

			if built then
				built.Parent = instance
			end
		end
	else
		(instance :: any).Value = value
	end

	return instance
end

function Mirror.Build(name: string, data: Data, parent: Instance): Folder
	local folder = build(name, data) :: Folder

	watchFolder(folder, data)
	folder.Parent = parent

	return folder
end

return Mirror
