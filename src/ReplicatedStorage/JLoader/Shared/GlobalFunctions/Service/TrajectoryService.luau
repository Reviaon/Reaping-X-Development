local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent:WaitForChild("Signal"))
local DebugService = require(script.Parent:WaitForChild("DebugService"))

local TrajectoryService = {}

TrajectoryService.Settings = {
	--@ Seconds between points on a predicted arc; each gap is one blockcast.
	Step = 1 / 30,

	--@ Seconds of flight an arc is followed before giving up on a landing.
	MaxFlightTime = 3,

	--@ Seconds another client's view of a character trails its owner; landings on anyone but the local character wait this long.
	ObserverLag = 0.15,

	--@ Seconds a debug path stays drawn after it finishes.
	DebugLifetime = 4,

	--@ Thickness of a drawn path segment, in studs.
	DebugWidth = 0.12,

	--@ Studs between points of a traced path.
	TraceSpacing = 0.5,

	--@ Slope in degrees below which a surface counts as floor, and above 180 minus it as ceiling.
	FloorSlope = 45,

	--@ Colour per path kind.
	Colors = {
		Knockback = Color3.fromRGB(255, 150, 40),
		Lunge = Color3.fromRGB(255, 230, 60),
		Launch = Color3.fromRGB(60, 200, 255),
		Trace = Color3.fromRGB(255, 255, 255),
		Landing = Color3.fromRGB(255, 60, 60),
	},

	--@ Draw a path as a beam from the root to an attachment sweeping along it, instead of segment parts.
	PathBeam = true,

	--@ Seconds the path attachment takes to sweep from the body to the far end of the path; it parks there after.
	BeamSweep = 0.25,

	--@ Beam width at the root and at the path attachment, in studs.
	BeamWidth = 0.35,
	BeamName = "@trajectory_beam",

	--@ Workspace folder the debug geometry is drawn into.
	DebugName = "@trajectory_debug",
	DebugHud = false, --@ Hardcoded debug to display trajectory information on the HUD
}

TrajectoryService.Landed = Signal.new()

local world = workspace:WaitForChild("World")

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
castParams.RespectCanCollide = true
castParams.FilterDescendantsInstances = { world:WaitForChild("Live"), world:WaitForChild("Visuals") }

local function surfaceOf(slope: number): string
	local floor = TrajectoryService.Settings.FloorSlope

	if slope < floor then return "Floor" end
	if slope > 180 - floor then return "Ceiling" end

	return "Wall"
end

local function describe(hit: RaycastResult, origin: Vector3, center: Vector3, velocity: Vector3, time: number)
	local normal = hit.Normal
	local speed = velocity.Magnitude
	local slope = math.deg(math.acos(math.clamp(normal:Dot(Vector3.yAxis), -1, 1)))
	local impact = speed > 0 and math.deg(math.asin(math.clamp(-velocity.Unit:Dot(normal), -1, 1))) or 0

	return {
		Origin = origin,
		Position = hit.Position,
		Center = center,
		Normal = normal,
		Instance = hit.Instance,
		Material = hit.Material.Name,
		Surface = surfaceOf(slope),
		Slope = slope,
		ImpactAngle = impact,
		Speed = speed,
		Velocity = velocity,
		Time = time,
	}
end

function TrajectoryService.Arc(origin: Vector3, velocity: Vector3, size: Vector3)
	local settings = TrajectoryService.Settings
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local points = { origin }
	local previous = origin
	local elapsed = 0

	while elapsed < settings.MaxFlightTime do
		local nextTime = math.min(elapsed + settings.Step, settings.MaxFlightTime)
		local nextPoint = origin + velocity * nextTime + gravity * (0.5 * nextTime * nextTime)
		local travel = nextPoint - previous

		if travel.Magnitude > 1e-3 then
			local hit = workspace:Blockcast(CFrame.new(previous), size, travel, castParams)

			if hit then
				local center = previous + travel.Unit * hit.Distance
				local time = elapsed + (nextTime - elapsed) * (hit.Distance / travel.Magnitude)

				table.insert(points, center)
				return points, describe(hit, origin, center, velocity + gravity * time, time)
			end
		end

		table.insert(points, nextPoint)
		previous = nextPoint
		elapsed = nextTime
	end

	return points, nil
end

function TrajectoryService.PredictLanding(origin: Vector3, velocity: Vector3, size: Vector3)
	local _, landing = TrajectoryService.Arc(origin, velocity, size)
	return landing
end

function TrajectoryService.LandingDelay(character: Model, landing): number
	local wait = typeof(landing.At) == "number" and landing.At - workspace:GetServerTimeNow() or (landing.Time or 0)

	if RunService:IsClient() and character ~= Players.LocalPlayer.Character then
		wait += TrajectoryService.Settings.ObserverLag
	end

	return math.max(wait, 0)
end

function TrajectoryService.IsDrawing(): boolean
	return RunService:IsClient() and DebugService.IsEnabled()
end

local function container(): Folder
	local name = TrajectoryService.Settings.DebugName
	local existing = workspace:FindFirstChild(name)
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

local function group(lifetime: number): Folder
	local folder = Instance.new("Folder")
	folder.Parent = container()
	Debris:AddItem(folder, lifetime)
	return folder
end

local function part(parent: Instance, color: Color3, size: Vector3, cframe: CFrame, shape: Enum.PartType?): BasePart
	local piece = Instance.new("Part")
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Material = Enum.Material.Neon
	piece.Color = color
	piece.Shape = shape or Enum.PartType.Block
	piece.Size = size
	piece.CFrame = cframe
	piece.Parent = parent
	piece.Transparency = 0.75
	return piece
end

local function segment(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 1e-3 then return end

	local width = TrajectoryService.Settings.DebugWidth
	part(parent, color, Vector3.new(width, width, length), CFrame.lookAt((from + to) / 2, to))
end

local function polyline(parent: Instance, points, color: Color3)
	for index = 2, #points do
		segment(parent, points[index - 1], points[index], color)
	end
end

local function alongPath(points, lengths: { number }, distance: number): Vector3
	for index = 2, #points do
		if distance <= lengths[index] then
			local span = lengths[index] - lengths[index - 1]
			local alpha = span > 0 and (distance - lengths[index - 1]) / span or 1
			return points[index - 1]:Lerp(points[index], alpha)
		end
	end

	return points[#points]
end

local function pathBeam(parent: Instance, root: BasePart, points, color: Color3)
	if #points < 2 then return end

	local settings = TrajectoryService.Settings
	local lengths = { 0 }

	for index = 2, #points do
		lengths[index] = lengths[index - 1] + (points[index] - points[index - 1]).Magnitude
	end

	local total = lengths[#lengths]
	if total <= 1e-3 then return end

	local origin = Instance.new("Attachment")
	origin.Name = settings.BeamName
	origin.Parent = root

	local cursor = Instance.new("Attachment")
	cursor.Name = settings.BeamName
	cursor.WorldPosition = points[1]
	cursor.Parent = workspace.Terrain

	local beam = Instance.new("Beam")
	beam.Name = settings.BeamName
	beam.Attachment0 = origin
	beam.Attachment1 = cursor
	beam.Color = ColorSequence.new(color)
	beam.Width0 = settings.BeamWidth
	beam.Width1 = settings.BeamWidth
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(0.2)
	beam.Segments = 1
	beam.Parent = parent

	local started = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		if not parent.Parent or not root.Parent then
			connection:Disconnect()
			origin:Destroy()
			cursor:Destroy()
			return
		end

		local alpha = math.min((os.clock() - started) / math.max(settings.BeamSweep, 1e-3), 1)
		cursor.WorldPosition = alongPath(points, lengths, alpha * total)
	end)

	parent.Destroying:Connect(function()
		connection:Disconnect()
		origin:Destroy()
		cursor:Destroy()
	end)
end

function TrajectoryService.Trace(character: Model, duration: number, color: Color3?)
	if not TrajectoryService.IsDrawing() then return end

	local body = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not body then return end

	local settings = TrajectoryService.Settings
	local parent = group(duration + settings.DebugLifetime)
	local last = body.Position
	local stop = os.clock() + duration
	local connection

	connection = RunService.RenderStepped:Connect(function()
		if os.clock() > stop or not body.Parent or not parent.Parent then
			connection:Disconnect()
			return
		end

		local position = body.Position

		if (position - last).Magnitude >= settings.TraceSpacing then
			segment(parent, last, position, color or settings.Colors.Trace)
			last = position
		end
	end)
end

function TrajectoryService.DrawRecipe(character: Model, recipe)
	if not TrajectoryService.IsDrawing() then return end
	if typeof(recipe) ~= "table" or typeof(recipe.start) ~= "Vector3" or typeof(recipe.finish) ~= "Vector3" then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local settings = TrajectoryService.Settings
	local color = settings.Colors[recipe.id and "Knockback" or "Lunge"]
	local height = Vector3.new(0, root.Position.Y, 0)
	local to = recipe.finish + height
	local parent = group(recipe.curve.duration + settings.DebugLifetime)

	if settings.PathBeam then
		pathBeam(parent, root, { recipe.start + height, to }, color)
	else
		segment(parent, recipe.start + height, to, color)
	end

	part(parent, color, Vector3.one * 0.4, CFrame.new(to), Enum.PartType.Ball)

	TrajectoryService.Trace(character, recipe.curve.duration + 0.3)
end

function TrajectoryService.DrawLaunch(character: Model, velocity: Vector3, landing)
	if not TrajectoryService.IsDrawing() then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local settings = TrajectoryService.Settings
	local known = typeof(landing) == "table" and typeof(landing.Position) == "Vector3"
	local origin = known and typeof(landing.Origin) == "Vector3" and landing.Origin or root.Position
	local flight = known and landing.Time or settings.MaxFlightTime
	local parent = group(flight + settings.DebugLifetime)

	local points = TrajectoryService.Arc(origin, velocity, root.Size)

	if settings.PathBeam then
		pathBeam(parent, root, points, settings.Colors.Launch)
	else
		polyline(parent, points, settings.Colors.Launch)
	end

	TrajectoryService.Trace(character, flight + 1)

	if not known then return end

	local marker = part(parent, settings.Colors.Landing, Vector3.one * 0.6, CFrame.new(landing.Position), Enum.PartType.Ball)
	segment(parent, landing.Position, landing.Position + landing.Normal * 2, settings.Colors.Landing)

	if TrajectoryService.Settings.DebugHud then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(230, 70)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = marker
		billboard.Parent = marker

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BackgroundTransparency = 0.35
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Text = string.format("%s · %s\nslope %d° · impact %d°\n%.0f studs/s · %.2fs",
			tostring(landing.Surface), tostring(landing.Material), math.round(landing.Slope or 0),
			math.round(landing.ImpactAngle or 0), landing.Speed or 0, landing.Time or 0)
		label.Parent = billboard

		task.delay(TrajectoryService.LandingDelay(character, landing), function()
			local body = character:FindFirstChild("Torso") or root
			if not label.Parent or not body.Parent then return end

			label.Text ..= string.format("\nlanded Δ %.1f studs", (body.Position - (landing.Center or landing.Position)).Magnitude)
		end)
	end
end

return TrajectoryService
