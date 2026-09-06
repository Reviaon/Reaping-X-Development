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

	Payloads are broadcast to every client, so arrivals are distance-culled against the local
	character before anything is played -- see the CullingConfig sibling module.
]]

--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)
local EffectService = Jloader.GetService("EffectService")

local ClientEffects = Jloader.CreateHandler({
	Name = script.Name,
})

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--@ Constants
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Effects = Modules:WaitForChild("Effects")

local PATH_SEPARATOR = "."

--@ Distance culling. Tuning lives in the sibling config, not here.
local CullingConfig = require(script.CullingConfig)
local LocalPlayer = Players.LocalPlayer

--@ Payloads arrive as plain tables (ByteNet drops metatables), so give them the same
--@ GlobalFunctions fallback ClientController has - that is what lets a visual read
--@ Info.EffectService or Info.GetPath without requiring the framework in every effect module.
local function WithTools(Info)
	if typeof(Info) ~= "table" or getmetatable(Info) then
		return Info
	end

	return setmetatable(Info, { __index = Jloader.GlobalFunctions })
end

--@ A world position out of whatever an Info key holds. Payloads carry a Model most of the
--@ time, but a raw part, attachment, CFrame or Vector3 all describe a spot just as well.
local function PositionOf(value)
	local kind = typeof(value)

	if kind == "Vector3" then return value end
	if kind == "CFrame" then return value.Position end
	if kind ~= "Instance" then return nil end

	if value:IsA("BasePart") then return value.Position end
	if value:IsA("Attachment") then return value.WorldPosition end

	--@ GetPivot covers a Model whose PrimaryPart was never assigned - common on imported
	--@ rigs, and the same gap that silently breaks EffectService:Weld.
	if value:IsA("Model") then
		local primary = value.PrimaryPart or value:FindFirstChild("HumanoidRootPart")
		return primary and primary.Position or value:GetPivot().Position
	end

	return nil
end

--@ Returns the effect's origin position and the instance it came from (needed to tell whether
--@ the effect is the local player's own). rawget, because Info may already carry the
--@ GlobalFunctions __index fallback and a key like "Target" could resolve against that.
local function ResolveOrigin(Info)
	if typeof(Info) ~= "table" then return nil, nil end

	for _, key in CullingConfig.OriginKeys do
		local candidate = rawget(Info, key)
		if candidate ~= nil then
			local position = PositionOf(candidate)
			if position then return position, candidate end
		end
	end

	return nil, nil
end

--@ Where the viewer is. Falls back to the camera so effects still play in the window between
--@ joining and the character replicating, rather than every one of them being culled.
local function ViewerPosition()
	local character = LocalPlayer and LocalPlayer.Character
	local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
	if root then return root.Position end

	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

local function IsLocalOrigin(source)
	local character = LocalPlayer and LocalPlayer.Character
	if not character or typeof(source) ~= "Instance" then return false end

	return source == character or source:IsDescendantOf(character)
end

--@ Effect lookup tables (keys are always lower-cased)
local ByPath = {} --@ ["combat.weapons.staffvisuals"] = module
local ByName = {} --@ ["staffvisuals"]              = module   (bare-name fallback)

--@ Build a module's dotted path relative to the Effects folder,
--  e.g. Effects.Combat.Weapons.StaffVisuals -> "Combat.Weapons.StaffVisuals"
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
	Info = WithTools(Info)

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

--@ Whether this payload is close enough to the viewer to be worth rendering. EffectService
--@ broadcasts with :FireAll, so this is the only thing standing between a client and every
--@ effect in the match. Decided once, on arrival - see CullingConfig for the tuning and for
--@ why this is independent of StreamingEnabled.
function ClientEffects:PassesCulling(Data)
	if not CullingConfig.Enabled then return true end

	local pathKey = typeof(Data.Effect) == "string" and string.lower(Data.Effect) or nil
	if pathKey and CullingConfig.AlwaysPlay[pathKey] then return true end

	local origin, source = ResolveOrigin(Data.Info)
	if not origin then
		--@ Nothing to measure against. Fail open unless the config says otherwise, so an
		--@ effect with an unrecognised Info shape degrades to the pre-culling behaviour.
		return not CullingConfig.CullUnresolved
	end

	if CullingConfig.AlwaysPlayLocal and IsLocalOrigin(source) then return true end

	local viewer = ViewerPosition()
	if not viewer then return true end

	local limit = CullingConfig.DistanceOverrides[pathKey] or CullingConfig.MaxDistance
	if typeof(limit) ~= "number" or limit <= 0 then return true end

	--@ Squared compare keeps a sqrt off a path that runs for every broadcast effect.
	local offset = origin - viewer
	return offset:Dot(offset) <= limit * limit
end

--@ Dispatch a raw payload fired from the server (or locally)
function ClientEffects:Fire(Data)
	if typeof(Data) ~= "table" then return end
	if not Data.Effect then warn("[ClientEffects]: Fire payload missing an 'Effect' path.") return end
	if not Data.Info then warn("[ClientEffects]: Fire payload missing an 'Info' table.") return end

	if not self:PassesCulling(Data) then return end

	return self:Play(Data.Effect, Data.Info, Data.Method)
end

--@ Start Method
function ClientEffects:Init()
	--@ Every weapon visual emits through ForgeVFX, so its caches and services have to be
	--@ up before any effect can play. init() is guarded, so calling it here is safe.
	Jloader.GlobalFunctions.ForgeVFX.init()

	self:LoadEffects()

	EffectService.CreateVisual:Connect(function(Data)
		self:Fire(Data)
	end)
end

return ClientEffects
