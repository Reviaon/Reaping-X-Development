local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local EffectService = Jloader.GlobalFunctions.EffectService

local Settings = {
	Assets = { "Storage", "Particles", "UniversalVFX" }, --@ Folder under ReplicatedStorage holding the notice assets
	Parent = { "World", "Visuals" }, --@ Workspace folder the clones go under
	Lifetime = 1.5, --@ Seconds when the notice names none
}

local Notice = {}

local function find(root: Instance, path: { string }): Instance?
	local found: Instance? = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function anchorOf(character: Model, name: string?): Instance?
	local found = if name then character:FindFirstChild(name, true) else nil

	if found and (found:IsA("Bone") or found:IsA("BasePart")) then return found end

	return character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
end

local function positionOf(anchor: Instance): Vector3
	return if anchor:IsA("Bone") then anchor.TransformedWorldCFrame.Position else (anchor :: BasePart).Position
end

local function hide(effect: Instance)
	local parts = effect:GetDescendants()
	table.insert(parts, effect)

	for _, part in parts do
		if not part:IsA("BasePart") then continue end

		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
end

function Notice.Emit(Info)
	local character = rawget(Info, "Character")
	local name = rawget(Info, "Visual")

	if typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent then return end
	if typeof(name) ~= "string" then return end

	local assets = find(ReplicatedStorage, Settings.Assets)
	local template = assets and assets:FindFirstChild(name)

	if not template then
		warn(`[Notice] No asset named "{name}" under {table.concat(Settings.Assets, ".")}.`)
		return
	end

	local head = rawget(Info, "Head")
	local anchor = anchorOf(character, if typeof(head) == "string" then head else nil)
	if not anchor then return end

	local offset = rawget(Info, "Offset")
	local lift = (if typeof(offset) == "Vector3" then offset else Vector3.zero) * character:GetScale()

	local lifetime = rawget(Info, "Lifetime")
	lifetime = if typeof(lifetime) == "number" then lifetime else Settings.Lifetime

	local effect = EffectService.new({ Effect = template })
	if not effect.Effect then return end

	hide(effect.Effect)

	local function follow()
		if anchor.Parent then
			effect:SetCFrame(CFrame.new(positionOf(anchor) + lift))
		end
	end

	follow()
	effect:SetParent(find(workspace, Settings.Parent) or workspace)
	effect:Play()

	local connection = RunService.PreRender:Connect(follow)

	task.delay(lifetime, function()
		connection:Disconnect()
		effect:Destroy()
	end)
end

Notice.Settings = Settings

return Notice
