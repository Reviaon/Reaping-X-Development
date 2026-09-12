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

	--@ Seconds the debug ray stays after its path ends, pointing from the body to where the path ended.
	DebugLifetime = 1,

	--@ Thickness of the debug ray, in studs.
	DebugWidth = 0.2,

	--@ Diameter of the ball marking where a knockback or launch lands the victim, and length of the surface normal drawn from a launch's.
	MarkerSize = 0.6,
	NormalLength = 2,

	--@ Seconds ahead on the path the ray reaches from the root; math.huge always reaches the path's end.
	RayLookAhead = 0.2,

	--@ Slope in degrees below which a surface counts as floor, and above 180 minus it as ceiling.
	FloorSlope = 45,

	--@ Colour of the ray per path kind.
	Colors = {
		Knockback = Color3.fromRGB(255, 60, 60),
		Lunge = Color3.fromRGB(255, 230, 60),
		Launch = Color3.fromRGB(255, 60, 60),
		Landing = Color3.fromRGB(255, 60, 60),
	},

	--@ Workspace folder the debug geometry is drawn into, and the names of each ray and landing marker.
	DebugName = "@trajectory_debug",
	RayName = "@trajectory_ray",
	MarkerName = "@trajectory_landing",
	DebugHud = false, --@ Hardcoded debug to display trajectory information on the HUD
}

TrajectoryService.Landed = Signal.new()

local world = workspace:WaitForChild("World")

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
castParams.RespectCanCollide = true
castParams.FilterDescendantsInstances = { world:WaitForChild("Live"), world:WaitForChild("Visuals") }

local rays = setmetatable({}, { __mode = "k" })

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

local function lagOf(character: Model): number
	if RunService:IsClient() and character ~= Players.LocalPlayer.Character then
		return TrajectoryService.Settings.ObserverLag
	end

	return 0
end

function TrajectoryService.LandingDelay(character: Model, landing): number
	local wait = typeof(landing.At) == "number" and landing.At - workspace:GetServerTimeNow() or (landing.Time or 0)

	return math.max(wait + lagOf(character), 0)
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
	piece.Transparency = 0.5
	return piece
end

local function marker(color: Color3, position: Vector3, normal: Vector3?, lifetime: number): BasePart
	local settings = TrajectoryService.Settings
	local ball = part(container(), color, Vector3.one * settings.MarkerSize, CFrame.new(position), Enum.PartType.Ball)
	ball.Name = settings.MarkerName

	if normal and normal.Magnitude > 1e-3 then
		local width = settings.DebugWidth
		local tip = position + normal.Unit * settings.NormalLength
		part(ball, color, Vector3.new(width, width, settings.NormalLength), CFrame.lookAt((position + tip) / 2, tip))
	end

	Debris:AddItem(ball, math.max(lifetime, 0) + settings.DebugLifetime)
	return ball
end

local function retire(character: Model, ray)
	ray.connection:Disconnect()
	ray.part:Destroy()

	if rays[character] == ray then
		rays[character] = nil
	end
end

local function step(character: Model, ray, body: BasePart)
	if not body.Parent or not ray.part.Parent then
		retire(character, ray)
		return
	end

	local settings = TrajectoryService.Settings
	local path = ray.path
	local at = workspace:GetServerTimeNow() - path.lag

	if at > path.ends + settings.DebugLifetime then
		retire(character, ray)
		return
	end

	local origin = body.Position
	local tip = path.position(math.min(at + settings.RayLookAhead, path.ends), origin)
	local offset = tip - origin
	local length = offset.Magnitude
	local width = settings.DebugWidth

	if length < width then
		ray.part.Size = Vector3.one * width
		ray.part.CFrame = CFrame.new(origin)
		return
	end

	ray.part.Size = Vector3.new(width, width, length)
	ray.part.CFrame = CFrame.lookAt(origin + offset / 2, tip)
end

local function follow(character: Model, color: Color3, position: (number, Vector3) -> Vector3, ends: number, lag: number): BasePart?
	local body = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not body then return nil end

	local ray = rays[character]

	if not ray then
		local settings = TrajectoryService.Settings
		local piece = part(container(), color, Vector3.one * settings.DebugWidth, CFrame.new(body.Position))
		piece.Name = settings.RayName

		ray = { part = piece }
		ray.connection = RunService.RenderStepped:Connect(function()
			step(character, ray, body)
		end)

		rays[character] = ray
	end

	ray.part.Color = color
	ray.path = { position = position, ends = ends, lag = lag }

	return ray.part
end

function TrajectoryService.DrawRecipe(character: Model, recipe, evaluate)
	if not TrajectoryService.IsDrawing() then return end
	if typeof(recipe) ~= "table" or typeof(recipe.startTime) ~= "number" or typeof(evaluate) ~= "function" then return end

	local colors = TrajectoryService.Settings.Colors
	local color = colors[recipe.id and "Knockback" or "Lunge"]
	local ends = recipe.startTime + recipe.curve.duration

	follow(character, color, function(at, origin)
		local flat = evaluate(recipe, at)
		return Vector3.new(flat.X, origin.Y, flat.Z)
	end, ends, 0)

	local body = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not recipe.id or not body or typeof(recipe.finish) ~= "Vector3" then return end

	marker(color, Vector3.new(recipe.finish.X, body.Position.Y, recipe.finish.Z), nil, ends - workspace:GetServerTimeNow())
end

function TrajectoryService.DrawLaunch(character: Model, velocity: Vector3, landing)
	if not TrajectoryService.IsDrawing() then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local settings = TrajectoryService.Settings
	local known = typeof(landing) == "table" and typeof(landing.Position) == "Vector3"
	local origin = known and typeof(landing.Origin) == "Vector3" and landing.Origin or root.Position
	local flight = known and landing.Time or settings.MaxFlightTime
	local start = known and typeof(landing.At) == "number" and landing.At - landing.Time or workspace:GetServerTimeNow()
	local gravity = Vector3.new(0, -workspace.Gravity, 0)

	follow(character, settings.Colors.Launch, function(at)
		local time = math.clamp(at - start, 0, flight)
		return origin + velocity * time + gravity * (0.5 * time * time)
	end, start + flight, lagOf(character))

	if not known then return end

	local ball = marker(settings.Colors.Landing, landing.Position, landing.Normal, TrajectoryService.LandingDelay(character, landing))

	if not settings.DebugHud then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(230, 70)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = ball
	billboard.Parent = ball

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

return TrajectoryService
