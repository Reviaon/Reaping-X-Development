local ServerStorage = game:GetService("ServerStorage")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Rig = require("../MobService/Body/Rig")
local Types = require("./Types")

type Profile = Types.Profile
type Settings = Types.Settings

local Swap = {}

local GlobalFunctions = Jloader.GlobalFunctions

local PROBE_HEIGHT = 10
local PROBE_DEPTH = 60
local FALLBACK_DROP = 3

local function live(): Instance?
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Live")
end

local function ground(position: Vector3, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(position + Vector3.yAxis * PROBE_HEIGHT, -Vector3.yAxis * PROBE_DEPTH, params)

	return if result then result.Position else nil
end

local function ignoring(model: Model?): { Instance }
	local ignore: { Instance } = {}
	local folder = live()

	if folder then
		table.insert(ignore, folder)
	end

	if model then
		table.insert(ignore, model)
	end

	return ignore
end

local function box(player: Player, settings: Settings, create: boolean): Instance?
	local stash = ServerStorage:FindFirstChild(settings.StashName)

	if not stash and create then
		local folder = Instance.new("Folder")
		folder.Name = settings.StashName
		folder.Parent = ServerStorage
		stash = folder
	end

	if not stash then return nil end

	local held = stash:FindFirstChild(tostring(player.UserId))

	if not held and create then
		local folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = stash
		held = folder
	end

	return held
end

local function stashTools(place: Instance?, held: Instance)
	if not place then return end

	for _, child in place:GetChildren() do
		if child:IsA("Tool") then
			child.Parent = held
		end
	end
end

local function settle(model: Model, profile: Profile)
	local config = profile.Config
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	Rig.Activate(model, humanoid)

	humanoid.AutoRotate = true
	humanoid.WalkSpeed = profile.Entry.walk_speed or config.walk_speed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = profile.Entry.jump or 0
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
end

function Swap.Stash(player: Player, character: Model, settings: Settings)
	local held = box(player, settings, true)
	if not held then return end

	stashTools(player:FindFirstChildOfClass("Backpack"), held)
	stashTools(character, held)
end

function Swap.Guard(player: Player, model: Model, settings: Settings): { RBXScriptConnection }
	local function keep(child: Instance)
		if not child:IsA("Tool") or child:GetAttribute(GlobalFunctions.CharacterService.MorphAbilityAttribute) ~= nil then return end

		task.defer(function()
			local held = box(player, settings, true)
			if not held or child.Parent == held then return end

			if held:FindFirstChild(child.Name) then
				child:Destroy()
			else
				child.Parent = held
			end
		end)
	end

	local guards = { model.ChildAdded:Connect(keep) }
	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		table.insert(guards, backpack.ChildAdded:Connect(keep))

		for _, child in backpack:GetChildren() do
			keep(child)
		end
	end

	return guards
end

function Swap.Unstash(player: Player, settings: Settings)
	local held = box(player, settings, false)
	if not held then return end

	task.defer(function()
		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)

		if backpack then
			for _, tool in held:GetChildren() do
				local fresh = backpack:FindFirstChild(tool.Name)

				if fresh and fresh:IsA("Tool") then
					fresh:Destroy()
				end

				tool.Parent = backpack
			end
		end

		held:Destroy()
	end)
end

function Swap.Forget(player: Player, settings: Settings)
	local held = box(player, settings, false)

	if held then
		held:Destroy()
	end
end

function Swap.Body(profile: Profile, frame: CFrame, character: Model): Model
	local look = frame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local floor = ground(frame.Position, ignoring(character)) or frame.Position - Vector3.yAxis * FALLBACK_DROP

	return Rig.Spawn(profile.Kind.Prototype, floor, yaw)
end

function Swap.Possess(player: Player, character: Model?, model: Model, profile: Profile)
	local CharacterService = GlobalFunctions.CharacterService
	local CharacterProfile = GlobalFunctions.ServerController.CharacterProfile

	model.Name = player.Name
	model:SetAttribute(CharacterService.MorphAttribute, profile.Name)
	model:SetAttribute(CharacterService.MorphProfileAttribute, profile.Json)
	model:SetAttribute(CharacterProfile.NoPackageAttribute, true)

	settle(model, profile)

	model:GetAttributeChangedSignal(CharacterProfile.LoadedAttribute):Once(function()
		settle(model, profile)
	end)

	model.Parent = workspace

	if character then
		character:Destroy()
	end

	player.Character = model

	local root = model.PrimaryPart

	if root and root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(player)
	end
end

function Swap.Place(character: Model, frame: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end

	local bounds, size = character:GetBoundingBox()
	local height = root.Position.Y - (bounds.Position.Y - size.Y / 2)
	local floor = ground(frame.Position, ignoring(character)) or frame.Position
	local look = frame.LookVector * Vector3.new(1, 0, 1)
	local position = floor + Vector3.yAxis * height
	local facing = CFrame.lookAt(position, position + (if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis))

	character:PivotTo(facing * root.CFrame:ToObjectSpace(character:GetPivot()))
end

return Swap
