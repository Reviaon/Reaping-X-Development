-- @ Start
local PhysicsService = {}

-- @ Services
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- @ Modules
local Trove = require(script.Parent.Parent:WaitForChild("Trove"))

--[[
	PhysicsService.ApplyImpulse(controller, settings) -> Trove | nil

	Applies a configurable BodyVelocity-based impulse to the controller's character.
	Returns a Trove instance; call :Destroy() on it to cancel the impulse early.
	Returns nil if a blockcast detects an obstacle and the impulse is suppressed.

	Settings:
		speed            number        Initial speed.                             Default: 40
		direction        Vector3       World-space direction. Normalized on use.  Default: root.LookVector
		duration         number        Total impulse lifetime in seconds.         Default: 0.8
		falloff          number        Tween duration for speed → 0.             Default: duration
		falloffStyle     EasingStyle   Easing style for falloff tween.           Default: Linear
		falloffDirection EasingDirection                                          Default: Out
		updateDirection  bool          Re-derive direction each RenderStep.      Default: false
		directionResolver (root)->Vector3  Custom per-frame direction function.  Default: root.LookVector
		lockToHorizontal bool          Zero Y component of velocity.             Default: true
		stopThreshold    number        Early destroy BodyVelocity below this speed. Default: 5
		maxForce         Vector3       Override MaxForce.                        Default: mass-based
		blockCast        bool          Enable per-frame obstacle check.          Default: false
		blockCastDistance number       Cast distance ahead in studs.             Default: 2.5
]]
function PhysicsService.ApplyImpulse(controller: {}, settings: {})
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local speed = settings.speed or 40
	local duration = settings.duration or 0.8
	local falloff = settings.falloff or duration
	local falloffStyle = settings.falloffStyle or Enum.EasingStyle.Linear
	local falloffDir = settings.falloffDirection or Enum.EasingDirection.Out
	local lockHorizontal = settings.lockToHorizontal ~= false -- default true
	local stopThreshold = settings.stopThreshold or 5
	local updateDirection = settings.updateDirection == true
	local directionResolver = settings.directionResolver

	local function resolveDirection(vec: Vector3): Vector3
		if lockHorizontal then
			vec = Vector3.new(vec.X, 0, vec.Z)
		end
		return vec.Magnitude > 0 and vec.Unit or Vector3.zero
	end

	local direction = resolveDirection(settings.direction or root.CFrame.LookVector)

	local doBlockCast = settings.blockCast == true -- default false
	local castDistance = settings.blockCastDistance or 2.5

	local _blockCastParams
	if doBlockCast then
		_blockCastParams = RaycastParams.new()
		_blockCastParams.FilterType = Enum.RaycastFilterType.Include
		local filterList = {}
		local worldFolder = workspace:FindFirstChild("World")
		if worldFolder then
			local mapFolder  = worldFolder:FindFirstChild("Map")
			local liveFolder = worldFolder:FindFirstChild("Live")
			if mapFolder  then table.insert(filterList, mapFolder)  end
			if liveFolder then table.insert(filterList, liveFolder) end
		end
		if #filterList > 0 then
			_blockCastParams.FilterDescendantsInstances = filterList
		else
			_blockCastParams = nil
		end
	end

	local speedValue = Instance.new("NumberValue")
	speedValue.Value = speed

	local tweenInfo = TweenInfo.new(falloff, falloffStyle, falloffDir)
	local tween = TweenService:Create(speedValue, tweenInfo, { Value = 0 })
	tween:Play()

	local mass = root.AssemblyMass
	local maxForce = settings.maxForce
		or (lockHorizontal
			and Vector3.new(mass, 0, mass) * 4e4
			or  Vector3.new(mass, mass, mass) * 4e4)

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = "@impulse_velocity"
	velocity.MaxForce = maxForce
	velocity.Velocity = direction * speed
	velocity.Parent = root

	local trove = Trove.new()

	trove:Add(tween)
	trove:Add(velocity)

	local start = os.clock()

	trove:Add(RunService.RenderStepped:Connect(function()
		if os.clock() - start > duration + 0.1 then
			trove:Destroy()
			return
		end

		if speedValue.Value <= stopThreshold then
			if velocity and velocity.Parent then
				velocity:Destroy()
			end
			return
		end

		if not (velocity and velocity.Parent) then return end

		-- @ Obstacle check: stop velocity if something is in the way
		if _blockCastParams then
			local castDir = direction * castDistance
			local hit = workspace:Blockcast(root.CFrame, Vector3.new(1, 2, 1), castDir, _blockCastParams)
			if hit then
				velocity:Destroy()
				return
			end
		end

		local currentDir = direction

		if updateDirection then
			if directionResolver then
				currentDir = resolveDirection(directionResolver(root))
			else
				currentDir = resolveDirection(root.CFrame.LookVector)
			end
		end

		velocity.Velocity = currentDir * speedValue.Value
	end))

	task.delay(duration, function()
		if velocity and velocity.Parent then
			velocity:Destroy()
		end
	end)

	return trove
end

return PhysicsService