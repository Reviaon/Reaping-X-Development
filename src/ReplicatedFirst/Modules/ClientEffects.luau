--@ ClientEffects Notes.

--[[
	Client-side effect handler.

	Receives visual effect requests fired from the server over
	EffectService.CreateVisual and resolves the requested module by a dotted
	PATH relative to the Effects folder, rather than a flat module name:

		"combat.effectfilename"  ->  Effects.Combat.EffectFilename
		"forcefield" ->  Effects.ForceField (root level)

	Path lookups are case-insensitive, so "Combat.Slash" and "combat.slash"
	resolve to the same module. A bare-name lookup ("forcefield") is kept as a
	fallback for convenience.

	Effect modules come in two shapes:
		- Function-style:  return function(Info) ... end
			fired with:  { Effect = "path", Info = {...} }
		- Method-style:    return { SomeMethod = function(Info) ... end }
			fired with:  { Effect = "path", Method = "SomeMethod", Info = {...} }
]]

--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)
local EffectService = Jloader.GetService("EffectService")

local ClientEffects = Jloader.CreateHandler({
	Name = script.Name,
})

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Constants
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Effects = Modules:WaitForChild("Effects")

local PATH_SEPARATOR = "."

--@ Effect lookup tables (keys are always lower-cased)
local ByPath = {} --@ ["combat.template"] = module
local ByName = {} --@ ["template"]        = module   (bare-name fallback)

--@ Build a module's dotted path relative to the Effects folder,
--  e.g. Effects.Combat.Template -> "Combat.Template"
local function getEffectPath(module: Instance): string
	local segments = { module.Name }
	local ancestor = module.Parent

	while ancestor and ancestor ~= Effects do
		table.insert(segments, 1, ancestor.Name)
		ancestor = ancestor.Parent
	end

	return table.concat(segments, PATH_SEPARATOR)
end

--@ Require every effect module and index it by path (and bare name)
function ClientEffects:LoadEffects()
	table.clear(ByPath)
	table.clear(ByName)

	for _, Visual in Effects:GetDescendants() do
		if not Visual:IsA("ModuleScript") then continue end

		local Loaded = require(Visual)
		ByPath[string.lower(getEffectPath(Visual))] = Loaded

		--@ First module of a given bare name wins the fallback slot
		local nameKey = string.lower(Visual.Name)
		if ByName[nameKey] == nil then
			ByName[nameKey] = Loaded
		end
	end
end

--@ Resolve an effect by dotted path ("combat.effectfilename"),
--  falling back to a bare-name lookup ("effectfilename").
function ClientEffects:Resolve(path)
	if typeof(path) ~= "string" then return nil end

	local key = string.lower(path)
	return ByPath[key] or ByName[key]
end

--@ Run a resolved effect. Handles function-style and method-style modules.
function ClientEffects:Play(path, Info, Method)
	local EffectMod = self:Resolve(path)
	if not EffectMod then
		warn(string.format("[ClientEffects]: No effect found at path '%s'.", tostring(path)))
		return
	end

	if Method then
		local fn = EffectMod[Method]
		if typeof(fn) ~= "function" then
			warn(string.format("[ClientEffects]: Effect '%s' has no method '%s'.", tostring(path), tostring(Method)))
			return
		end
		return fn(Info)
	end

	if typeof(EffectMod) ~= "function" then
		warn(string.format("[ClientEffects]: Effect '%s' is method-style; supply a Method to fire it.", tostring(path)))
		return
	end

	return EffectMod(Info)
end

--@ Dispatch a raw payload fired from the server (or locally)
function ClientEffects:Fire(Data)
	if typeof(Data) ~= "table" then return end
	if not Data.Effect then warn("[ClientEffects]: Fire payload missing an 'Effect' path.") return end
	if not Data.Info then warn("[ClientEffects]: Fire payload missing an 'Info' table.") return end

	return self:Play(Data.Effect, Data.Info, Data.Method)
end

--@ Start Method
function ClientEffects:Init()
	self:LoadEffects()

	EffectService.CreateVisual:Connect(function(Data)
		self:Fire(Data)
	end)
end

return ClientEffects
