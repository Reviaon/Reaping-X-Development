local Jloader = require("@game/ReplicatedStorage/JLoader")
local DebugService = Jloader.GlobalFunctions.DebugService

local Registry = require("./Core/Registry")
local Config = require("@self/Config")

local Inspect = {}

Inspect.Config = Config

local Sections = Registry.new(script.Sections, "inspect section")
local Verbs = Registry.new(script.Verbs, "inspect verb")

local function named(folder: Instance, word: string): string?
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") and string.lower(module.Name) == word then
			return module.Name
		end
	end

	return nil
end

function Inspect.Words(): { string }
	local words = { "all" }

	for _, folder in { script.Sections, script.Verbs } do
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				table.insert(words, string.lower(module.Name))
			end
		end
	end

	table.sort(words)

	return words
end

function Inspect.Near(mobs, origin: Vector3, all: boolean)
	local found = {}

	for mob in mobs do
		if not mob.Root then continue end

		local distance = (mob.Root.Position - origin).Magnitude

		if distance <= Config.Radius then
			table.insert(found, { Mob = mob, Distance = distance })
		end
	end

	table.sort(found, function(a, b)
		return a.Distance < b.Distance
	end)

	local selected = {}

	for index, entry in found do
		if not all and index > 1 then break end
		selected[index] = entry.Mob
	end

	return selected
end

local function report(mob, sections: { string }, origin: Vector3, now: number): string
	local lines = { string.format("— %s, %.0f studs —", mob.Name, (mob.Root.Position - origin).Magnitude) }

	for _, name in sections do
		for index, line in Sections[name].Report(mob, now) do
			table.insert(lines, if index == 1 then `{name}: {line}` else `    {line}`)
		end
	end

	return table.concat(lines, "\n")
end

function Inspect.Run(mobs, origin: Vector3, words: { string }, context): (string?, string?)
	local all, what = false, nil

	for _, word in words do
		local lowered = string.lower(word)

		if lowered == "all" then
			all = true
		elseif what == nil then
			what = lowered
		end
	end

	local section = what and named(script.Sections, what)
	local verb = what and not section and named(script.Verbs, what)

	if what and not section and not verb then
		return nil, `'{what}' is not one of: {table.concat(Inspect.Words(), ", ")}`
	end

	context.Mobs = mobs

	if verb and not Verbs[verb].Selects then
		return Verbs[verb].Run({}, context)
	end

	local selected = Inspect.Near(mobs, origin, all)

	if #selected == 0 then
		return nil, `no mob within {Config.Radius} studs`
	end

	if verb then
		return Verbs[verb].Run(selected, context)
	end

	local now = os.clock()
	local reports = {}

	for _, mob in selected do
		table.insert(reports, report(mob, if section then { section } else Config.Sections, origin, now))
	end

	return table.concat(reports, "\n")
end

function Inspect.Brief(mob): string?
	local rows = {}

	for _, row in Config.Overhead do
		local parts = {}

		for _, name in row do
			local brief = Sections[name].Brief(mob)

			if brief then
				table.insert(parts, brief)
			end
		end

		if #parts > 0 then
			table.insert(rows, table.concat(parts, Config.Separator))
		end
	end

	return if #rows > 0 then table.concat(rows, "\n") else nil
end

function Inspect.Publish(mob)
	local line = if DebugService.IsEnabled() and not mob.Destroyed then Inspect.Brief(mob) else nil
	if line == mob.Overhead then return end

	mob.Overhead = line
	mob.Model:SetAttribute(DebugService.Settings.Overhead, line)
end

return Inspect
