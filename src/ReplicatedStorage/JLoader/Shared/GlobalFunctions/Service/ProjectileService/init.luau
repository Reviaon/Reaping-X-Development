local ProjectileService = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartCache = require(script.Parent.Parent:WaitForChild("PartCache"))
local DebugService = require(script.Parent:WaitForChild("DebugService"))
local Config = require("@self/Config")

local pools = {}

local function visualsFolder(): Instance
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("Visuals") or workspace
end

local function poolFor(model: string)
	if pools[model] then return pools[model] end

	local folder = ReplicatedStorage.Storage.Models:FindFirstChild("Projectiles")
	local template = folder and folder:FindFirstChild(model)
	if not template or not template:IsA("BasePart") then return nil end

	pools[model] = PartCache.new(template, Config.PoolSize, visualsFolder())
	return pools[model]
end

local function debugSegment(a: Vector3, b: Vector3, color: Color3)
	if not DebugService.IsEnabled() then return end

	local length = (b - a).Magnitude
	if length < 0.01 then return end

	local part = Instance.new("Part")
	part.Name = "@ProjectileDebug"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.08, 0.08, length)
	part.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2)
	part.Parent = visualsFolder()

	Debris:AddItem(part, Config.Debug.Lifetime)
end

function ProjectileService.NewShot(origin: Vector3, direction: Vector3, projectile, shooter: Model?)
	local gravity = if typeof(projectile.gravity) == "number" then projectile.gravity else Config.Defaults.Gravity

	return {
		Origin = origin,
		Direction = direction.Unit,
		Speed = if typeof(projectile.speed) == "number" then projectile.speed else Config.Defaults.Speed,
		Gravity = Vector3.new(0, -workspace.Gravity * gravity, 0),
		MaxRange = if typeof(projectile.max_range) == "number" then projectile.max_range else Config.Defaults.Range,
		Model = projectile.model,
		Shooter = shooter,
		FiredAt = workspace:GetServerTimeNow(),
	}
end

function ProjectileService.PathAt(shot, t: number): Vector3
	return shot.Origin + shot.Direction * (shot.Speed * t) + shot.Gravity * (0.5 * t * t)
end

function ProjectileService.VelocityAt(shot, t: number): Vector3
	return shot.Direction * shot.Speed + shot.Gravity * t
end

function ProjectileService.Lifetime(shot): number
	return shot.MaxRange / shot.Speed
end

function ProjectileService.Params(shot, ignore: { Instance }?): RaycastParams
	local exclude = { visualsFolder() }

	if shot.Shooter then
		table.insert(exclude, shot.Shooter)
	end

	for _, instance in ignore or {} do
		table.insert(exclude, instance)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	return params
end

function ProjectileService.Cast(shot, from: number, to: number, params: RaycastParams): (RaycastResult?, number)
	local a = ProjectileService.PathAt(shot, from)
	local b = ProjectileService.PathAt(shot, to)
	local result = workspace:Raycast(a, b - a, params)
	local passes = 0

	while result and Config.PassThrough[result.Instance.Name] and passes < Config.MaxPasses do
		params:AddToFilter(result.Instance)
		result = workspace:Raycast(a, b - a, params)
		passes += 1
	end

	if not result then return nil, to end

	local length = (b - a).Magnitude
	local share = if length > 0 then result.Distance / length else 0

	return result, from + (to - from) * share
end

local function orient(position: Vector3, velocity: Vector3): CFrame
	return CFrame.lookAt(position, position + velocity) * Config.TipRotation
end

local function stick(pool, part: BasePart, result: RaycastResult, velocity: Vector3)
	local reach = part.Size.X / 2 - Config.Stick.Depth
	local placed = orient(result.Position, velocity)

	part.CFrame = placed * CFrame.new(-reach, 0, 0)

	local hit = result.Instance
	local weld

	if hit and not hit.Anchored then
		part.Anchored = false
		part.Massless = true

		weld = Instance.new("WeldConstraint")
		weld.Part0 = hit
		weld.Part1 = part
		weld.Parent = part
	end

	task.delay(Config.Stick.Time, function()
		if weld then
			weld:Destroy()
		end

		pool:ReturnPart(part)
	end)
end

function ProjectileService.Fire(shot, callbacks)
	callbacks = callbacks or {}

	local pool = shot.Model and poolFor(shot.Model)
	local part = pool and pool:GetPart()
	local params = ProjectileService.Params(shot, callbacks.ignore)
	local lifetime = ProjectileService.Lifetime(shot)
	local started = os.clock() - (if typeof(callbacks.elapsed) == "number" then math.max(callbacks.elapsed, 0) else 0)
	local last = 0
	local connection

	if part then
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = orient(shot.Origin, shot.Direction)
	end

	connection = RunService.Heartbeat:Connect(function()
		local now = math.min(os.clock() - started, lifetime)
		local result, at = ProjectileService.Cast(shot, last, now, params)
		local reached = ProjectileService.PathAt(shot, at)

		debugSegment(ProjectileService.PathAt(shot, last), reached, if result then Config.Debug.HitColor else Config.Debug.Color)

		if result then
			connection:Disconnect()

			if part then
				stick(pool, part, result, ProjectileService.VelocityAt(shot, at))
			end

			if callbacks.onHit then
				task.spawn(callbacks.onHit, result, at)
			end

			return
		end

		last = now

		if part then
			part.CFrame = orient(reached, ProjectileService.VelocityAt(shot, now))
		end

		if now >= lifetime then
			connection:Disconnect()

			if part then
				pool:ReturnPart(part)
			end

			if callbacks.onExpire then
				task.spawn(callbacks.onExpire)
			end
		end
	end)

	return connection
end

return ProjectileService
