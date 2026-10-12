local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DashDebris = {}

DashDebris.Settings = {
	--@ A Model whose PrimaryPart is the buried block; Top is the cap that takes the floor's look.
	--@ Its two parts are only templates: every piece is built from parts held in a PartCache
	Asset = "ReplicatedStorage/Storage/Particles/MovementVFX/DashGroundDebree",
	Parent = "Workspace/World/Visuals",
	Top = "Top",

	--@ Pieces made up front, and how many more are made at once if they ever run out
	Pool = 60,
	PoolGrowth = 30,

	--@ Never treated as floor
	Ignore = { "Workspace/World/Live", "Workspace/World/Visuals" },

	--@ Seconds after the dash starts that pieces keep appearing, one pair per Spacing studs travelled
	Window = 0.8,
	Spacing = 2,

	--@ Studs out to either side of the dash's line, and how far a piece may stray from that spot
	Side = 1.6,
	Jitter = 0.5,

	--@ The root axis each dash direction's pair is spread along, so the pieces flank the travel:
	--@ left and right of a forward or back dash, front and back of a sideways one
	Across = {
		W = "RightVector",
		S = "RightVector",
		A = "LookVector",
		D = "LookVector",
	},

	Scale = NumberRange.new(0.4, 1.4),
	Tilt = math.rad(25), --@ Most a piece leans off the floor's normal; its yaw is fully random

	--@ Share of the block left under the floor once it has risen
	Embed = 0.35,

	--@ Studs below the root the floor is looked for
	RayDepth = 8,

	Rise = 0.12,
	Lifetime = 1.2,
	Sink = 0.45,
}

local SIDES = { -1, 1 }

local random = Random.new()

local pool = nil

local function cacheOf(Info, source: BasePart, parent: Instance)
	local settings = DashDebris.Settings

	local template = source:Clone()
	template.CanQuery = false
	template.CanTouch = false

	local cache = Info.PartCache.new(template, settings.Pool, parent)
	cache.ExpansionSize = settings.PoolGrowth

	template:Destroy()

	return cache
end

--@ Built once, on the first dash this client draws.
local function poolFor(Info, parent: Instance)
	if pool then return pool end

	local settings = DashDebris.Settings
	local asset = Info.GetPath:ReadPath(settings.Asset)
	local block = asset and asset:IsA("Model") and asset.PrimaryPart
	local top = asset and asset:FindFirstChild(settings.Top)

	if not block or not top or not top:IsA("BasePart") then return nil end

	pool = {
		Blocks = cacheOf(Info, block, parent),
		Tops = cacheOf(Info, top, parent),
		BlockSize = block.Size,
		TopSize = top.Size,
		TopOffset = block.CFrame:ToObjectSpace(top.CFrame),
	}

	return pool
end

local function floorColor(result: RaycastResult): Color3?
	local instance = result.Instance

	if instance:IsA("Terrain") then
		local ok, color = pcall(instance.GetMaterialColor, instance, result.Material)
		return ok and color or nil
	end

	return instance.Color
end

local function spawnPiece(settings, pieces, root: BasePart, axis: string, side: number, params: RaycastParams)
	local across = root.CFrame[axis]
	local jitter = settings.Jitter

	local origin = root.Position
		+ across * side * (settings.Side + random:NextNumber(-jitter, jitter))
		+ across:Cross(Vector3.yAxis) * random:NextNumber(-jitter, jitter)

	local result = workspace:Raycast(origin, Vector3.new(0, -settings.RayDepth, 0), params)
	if not result then return end

	local scale = random:NextNumber(settings.Scale.Min, settings.Scale.Max)
	local block = pieces.Blocks:GetPart()
	local top = pieces.Tops:GetPart()

	block.Size = pieces.BlockSize * scale
	top.Size = pieces.TopSize * scale

	top.Material = result.Material
	top.MaterialVariant = result.Instance:IsA("Terrain") and "" or result.Instance.MaterialVariant
	top.Color = floorColor(result) or top.Color

	local up = result.Normal
	local height = block.Size.Y
	local tilt = settings.Tilt
	local offset = pieces.TopOffset

	local rest = CFrame.new(result.Position + up * height * (0.5 - settings.Embed))
		* CFrame.fromRotationBetweenVectors(Vector3.yAxis, up)
		* CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0)
		* CFrame.Angles(random:NextNumber(-tilt, tilt), 0, random:NextNumber(-tilt, tilt))

	--@ Rises and sinks along the floor's normal, keeping the orientation it was given
	local buried = -up * height * 1.5

	local targets = {
		[block] = rest,
		[top] = rest * (offset.Rotation + offset.Position * scale),
	}

	local rise = TweenInfo.new(settings.Rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local sink = TweenInfo.new(settings.Sink, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for part, target in targets do
		part.CFrame = target + buried
		TweenService:Create(part, rise, { CFrame = target }):Play()
	end

	task.delay(settings.Rise + settings.Lifetime, function()
		for part, target in targets do
			TweenService:Create(part, sink, { CFrame = target + buried }):Play()
		end
	end)

	task.delay(settings.Rise + settings.Lifetime + settings.Sink, function()
		pieces.Blocks:ReturnPart(block)
		pieces.Tops:ReturnPart(top)
	end)
end

--@ Follows Info.Character for the dash, leaving a pair of pieces either side of it as it travels
DashDebris.Trail = function(Info)
	local settings = DashDebris.Settings
	local character = Info.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local parent = Info.GetPath:ReadPath(settings.Parent)
	local pieces = root and parent and poolFor(Info, parent)

	if not pieces then return end

	local ignore = { character }

	for _, path in settings.Ignore do
		local instance = Info.GetPath:ReadPath(path)

		if instance then
			table.insert(ignore, instance)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true

	local axis = settings.Across[Info.Direction] or "RightVector"
	local began = os.clock()
	local last = root.Position
	local travelled = settings.Spacing
	local connection

	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or os.clock() - began > settings.Window then
			connection:Disconnect()
			return
		end

		local position = root.Position

		travelled += ((position - last) * Vector3.new(1, 0, 1)).Magnitude
		last = position

		if travelled < settings.Spacing then return end

		travelled = 0

		for _, side in SIDES do
			spawnPiece(settings, pieces, root, axis, side, params)
		end
	end)
end

return DashDebris
