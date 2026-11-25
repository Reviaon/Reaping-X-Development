local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("./Config")
local SoundTypes = require("../SoundTypes")

type Index = { [string]: SoundTypes.Entry }

local Registry = {
	Index = nil :: Index?,
	Sorted = {} :: { string },
	Last = {} :: { [string]: number },
	Cycles = setmetatable({} :: { [any]: { [string]: number } }, { __mode = "k" }),
	Shared = {},
	Rng = Random.new(),
}

local function Join(Prefix: string, Name: string): string
	return if Prefix == "" then Name else Prefix .. Config.Separator .. Name
end

local function Flatten(Group: SoundTypes.Group, Prefix: string, Index: Index)
	for Name, Value in Group do
		local Path = Join(Prefix, Name)

		if (Value :: any).Ids ~= nil then
			Index[Path] = Value :: SoundTypes.Entry
		else
			Flatten(Value :: SoundTypes.Group, Path, Index)
		end
	end
end

local function Walk(Node: Instance, Prefix: string, Index: Index)
	for _, Child in Node:GetChildren() do
		local Path = Join(Prefix, Child.Name)

		if Child:IsA("ModuleScript") then
			Flatten((require :: any)(Child) :: SoundTypes.Group, Path, Index)
		elseif Child:IsA("Folder") then
			Walk(Child, Path, Index)
		end
	end
end

function Registry.Build(): Index
	local Existing = Registry.Index
	if Existing then
		return Existing
	end

	local Index: Index = {}
	local Library = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild(Config.Library)
	Walk(Library, "", Index)

	local Sorted = {}
	for Path in Index do
		table.insert(Sorted, Path)
	end
	table.sort(Sorted)

	Registry.Index = Index
	Registry.Sorted = Sorted
	return Index
end

function Registry.Get(Path: string): SoundTypes.Entry?
	return Registry.Build()[Path]
end

function Registry.Under(Path: string, Prefix: string?): boolean
	if not Prefix or Prefix == "" or Path == Prefix then
		return true
	end

	local Head = Prefix .. Config.Separator
	return string.sub(Path, 1, #Head) == Head
end

function Registry.List(Prefix: string?): { string }
	Registry.Build()

	local Found = {}
	for _, Path in Registry.Sorted do
		if Registry.Under(Path, Prefix) then
			table.insert(Found, Path)
		end
	end
	return Found
end

function Registry.ContentId(Id: number): string
	return `rbxassetid://{Id}`
end

function Registry.Ids(Path: string): { string }
	local Entry = Registry.Get(Path)
	local Ids = {}

	if Entry then
		for _, Id in Entry.Ids do
			table.insert(Ids, Registry.ContentId(Id))
		end
	end
	return Ids
end

function Registry.Numbered(Entry: SoundTypes.Entry, Number: number): number
	local Count = #Entry.Ids
	local Wanted = math.max(math.floor(Number), 1)
	local Numbers = Entry.Numbers

	if Numbers then
		local Found = table.find(Numbers, Wanted)
		if Found and Found <= Count then
			return Found
		end
	elseif Wanted <= Count then
		return Wanted
	end

	return (Wanted - 1) % Count + 1
end

function Registry.Pick(Path: string, Variant: number?, Owner: Instance?, Number: number?): number?
	local Entry = Registry.Get(Path)
	if not Entry or #Entry.Ids == 0 then
		return nil
	end

	local Count = #Entry.Ids
	local Last = Registry.Last[Path]
	local Index: number

	if Variant then
		Index = math.clamp(math.floor(Variant), 1, Count)
	elseif Number then
		Index = Registry.Numbered(Entry, Number)
	elseif Entry.Cycle then
		local Key = Owner or Registry.Shared
		local Positions = Registry.Cycles[Key]

		if not Positions then
			Positions = {}
			Registry.Cycles[Key] = Positions
		end

		Index = (Positions[Path] or 0) % Count + 1
		Positions[Path] = Index
	elseif Config.AvoidRepeat and Count > 1 and Last then
		Index = Registry.Rng:NextInteger(1, Count - 1)
		if Index >= Last then
			Index += 1
		end
	else
		Index = Registry.Rng:NextInteger(1, Count)
	end

	Registry.Last[Path] = Index
	return Entry.Ids[Index]
end

function Registry.Category(Path: string): string
	local Stop = string.find(Path, Config.Separator, 1, true)
	return if Stop then string.sub(Path, 1, Stop - 1) else Path
end

return Registry
