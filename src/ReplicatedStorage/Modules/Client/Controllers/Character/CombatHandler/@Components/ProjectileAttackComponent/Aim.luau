local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require("./Config")

local Aim = {}

local cameraHandler = nil

local function camera()
	if not cameraHandler then
		local ok, handler = pcall(function()
			return require(ReplicatedStorage:WaitForChild("JLoader")).GetHandler("CameraHandler")
		end)

		if ok then
			cameraHandler = handler
		end
	end

	return cameraHandler
end

function Aim.HoldFov(projectile, held: boolean)
	local handler = camera()
	if not handler or typeof(handler.HoldFov) ~= "function" then return end

	handler:HoldFov(Config.FovKey, if held and typeof(projectile.aim_fov) == "number" then projectile.aim_fov else nil)
end

function Aim.Release(projectile)
	Aim.HoldFov(projectile, false)

	local handler = camera()

	if handler and typeof(projectile.release_shake) == "string" then
		handler:Shake(projectile.release_shake)
	end
end

function Aim.Point(controller, projectile): Vector3
	local view = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = view:ViewportPointToRay(mouse.X, mouse.Y)
	local range = if typeof(projectile.max_range) == "number" then projectile.max_range else Config.FallbackRange

	local ignore = { controller.Character }
	local world = workspace:FindFirstChild("World")
	local visuals = world and world:FindFirstChild("Visuals")

	if visuals then
		table.insert(ignore, visuals)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(ray.Origin, ray.Direction * range, params)

	return if result then result.Position else ray.Origin + ray.Direction * range
end

function Aim.Face(controller, state, projectile, dt: number)
	local root = controller.HumanoidRootPart
	local Humanoid = controller.Humanoid
	if not root or not Humanoid then return end

	local point = Aim.Point(controller, projectile)
	local origin = root.Position
	local offset = point - origin
	local flat = Vector3.new(offset.X, 0, offset.Z)

	state.aimPoint = point
	state.aimPitch = math.atan2(offset.Y, flat.Magnitude)

	if flat.Magnitude < Config.Facing.MinDistance then return end

	Humanoid.AutoRotate = false

	local goal = CFrame.lookAt(origin, origin + flat)
	local rate = projectile.face_rate

	if typeof(rate) == "number" then
		goal = root.CFrame.Rotation:Lerp(goal.Rotation, 1 - math.exp(-rate * dt)) + origin
	end

	root.CFrame = goal
end

function Aim.ShoulderPitch(Character: Model, point: Vector3?): number
	local torso = Character:FindFirstChild("Torso")
	if not torso or not point then return 0 end

	local offset = point - torso.CFrame * Vector3.new(0, Config.Pitch.ShoulderHeight, 0)

	return math.atan2(offset.Y, Vector3.new(offset.X, 0, offset.Z).Magnitude)
end

function Aim.PitchArms(Character: Model, view, settings, target: number, dt: number)
	local torso = Character:FindFirstChild("Torso")
	if not torso or typeof(settings) ~= "table" then return end

	local pitch = Config.Pitch
	local limit = math.rad(if typeof(settings.max) == "number" then settings.max else pitch.DefaultMax)
	local rate = if typeof(settings.rate) == "number" then settings.rate else pitch.DefaultRate
	local current = view.armPitch or 0

	target = math.clamp(target, -limit, limit)
	current += (target - current) * (1 - math.exp(-rate * dt))

	if target == 0 and math.abs(current) < pitch.Epsilon then
		current = 0
	end

	view.armPitch = current
	view.armSettings = settings
	view.baseC0 = view.baseC0 or setmetatable({}, { __mode = "k" })

	for _, name in settings.joints or {} do
		local joint = torso:FindFirstChild(name)
		if not joint or not joint:IsA("Motor6D") then continue end

		local base = view.baseC0[joint]

		if not base then
			if current == 0 then continue end

			base = joint.C0
			view.baseC0[joint] = base
		end

		joint.C0 = CFrame.new(base.Position) * CFrame.Angles(current, 0, 0) * base.Rotation

		if current == 0 then
			view.baseC0[joint] = nil
		end
	end
end

function Aim.RestoreArms(view)
	for joint, base in view.baseC0 or {} do
		if joint.Parent then
			joint.C0 = base
		end
	end

	view.baseC0 = nil
	view.armPitch = 0
end

function Aim.SendPitch(controller, state)
	local relay = controller.RangedRelay
	if not relay then return end

	local pitch = Config.Pitch
	local degrees = math.floor(math.deg(state.armPitch or 0) * 2 + 0.5) / 2
	local sent = state.sentPitch or 0
	local now = os.clock()

	if degrees == sent then return end
	if degrees ~= 0 and math.abs(degrees - sent) < pitch.SendStep then return end
	if degrees ~= 0 and state.sentPitchAt and now - state.sentPitchAt < pitch.SendInterval then return end

	state.sentPitch = degrees
	state.sentPitchAt = now
	relay.AimPitch:Fire(degrees)
end

return Aim
