-- @ Start
local PhysicsService = {}

-- @ Services
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- @ Modules
local Trove = require(script.Parent.Parent:WaitForChild("Trove"))

-- @ Stamped on every impulse mover so competing impulses can be arbitrated.
-- Any system that parents its own @impulse_velocity should stamp this too.
local IMPULSE_PRIORITY_ATTRIBUTE = "impulse_priority"
PhysicsService.ImpulsePriorityAttribute = IMPULSE_PRIORITY_ATTRIBUTE

local IMPULSE_NAME = "@impulse_velocity"
PhysicsService.ImpulseName = IMPULSE_NAME

local FACING_NAME = "@impulse_facing"
PhysicsService.FacingName = FACING_NAME

-- @ Holds the Humanoid's own AutoRotate across overlapping impulses, so the last one to finish
-- restores what the character actually had rather than what the previous impulse left behind.
local AUTO_ROTATE_ATTRIBUTE = "impulse_auto_rotate"

-- @ Stamped on the root by KnockbackService while it drives the CFrame. An impulse at or below that
-- priority is refused for as long as the drive runs, so a dash cannot fight a knockback.
local KNOCKBACK_PRIORITY_ATTRIBUTE = "knockback_priority"
local KNOCKBACK_UNTIL_ATTRIBUTE = "knockback_until"

-- @ LinearVelocity needs an Attachment. R6 roots carry RootAttachment and R15 RootRigAttachment;
-- anything else gets one made and kept, since an empty Attachment costs nothing and sharing one
-- avoids two systems each destroying the other's.
local ROOT_ATTACHMENTS = { "RootAttachment", "RootRigAttachment" }
local IMPULSE_ATTACHMENT_NAME = "@impulse_attachment"

function PhysicsService.ImpulseAttachment(root: BasePart): Attachment?
	if not root then return nil end

	for _, name in ROOT_ATTACHMENTS do
		local found = root:FindFirstChild(name)
		if found and found:IsA("Attachment") then
			return found
		end
	end

	local existing = root:FindFirstChild(IMPULSE_ATTACHMENT_NAME)
	if existing and existing:IsA("Attachment") then
		return existing
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = IMPULSE_ATTACHMENT_NAME
	attachment.Parent = root

	return attachment
end

function PhysicsService.GetImpulse(root: BasePart)
	if not root then return nil end
	return root:FindFirstChild(IMPULSE_NAME)
end

function PhysicsService.GetFacing(root: BasePart)
	if not root then return nil end
	return root:FindFirstChild(FACING_NAME)
end

--[[
	PhysicsService.ApplyImpulse(controller, settings) -> Trove | nil

	Applies a configurable LinearVelocity-based impulse to the controller's character.
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
		stopThreshold    number        Early destroy the mover below this speed.  Default: 5
		rampIn           number        Seconds to reach full speed from 0. Default: 0 (instant).
		                               A step change replicates badly to onlookers; a slope does not.
		maxForce         Vector3       Override MaxForce.                        Default: mass-based
		blockCast        bool          Enable per-frame obstacle check.          Default: false
		blockCastDistance number       Cast distance ahead in studs.             Default: 2.5
		influence        number        How much of the character's own walk velocity is
		                               folded back in each frame. 0 = the impulse owns
		                               movement outright, 1 = their full WalkSpeed adds
		                               on top, so held WASD steers, extends or eats the
		                               push and control returns gradually. Default: 0
		facing           Vector3       World direction the character turns to look along for the
		                               life of the impulse. Flattened to horizontal, so it is yaw
		                               only. Suppresses Humanoid.AutoRotate while it runs.
		                               Default: nil (no turn)
		facingResponsiveness number    How sharply that turn is taken.           Default: 100
		facingTorque     number        Override MaxTorque.                       Default: mass-based
		priority         number        Arbitration weight vs the active impulse. Default: 0
		                               A request is ignored while an impulse of a
		                               HIGHER priority is live; equal or greater
		                               priority supersedes it (latest wins).
]]
function PhysicsService.ApplyImpulse(controller: {}, settings: {})
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	--@ A negative influence would invert the player's own input, which is never wanted.
	local influence = math.max(settings.influence or 0, 0)

	local priority = settings.priority or 0

	local knockbackUntil = root:GetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE)

	if typeof(knockbackUntil) == "number"
		and workspace:GetServerTimeNow() < knockbackUntil
		and (root:GetAttribute(KNOCKBACK_PRIORITY_ATTRIBUTE) or 0) >= priority
	then
		return nil
	end

	local existing = PhysicsService.GetImpulse(root)

	if existing then
		
		if (existing:GetAttribute(IMPULSE_PRIORITY_ATTRIBUTE) or 0) > priority then
			return nil
		end

		existing:Destroy()

		local existingFacing = PhysicsService.GetFacing(root)
		if existingFacing then
			existingFacing:Destroy()
		end
	end

	local speed = settings.speed or 40
	local duration = settings.duration or 0.8
	local falloff = settings.falloff or duration
	local falloffStyle = settings.falloffStyle or Enum.EasingStyle.Linear
	local falloffDir = settings.falloffDirection or Enum.EasingDirection.Out
	local lockHorizontal = settings.lockToHorizontal ~= false -- default true
	local stopThreshold = settings.stopThreshold or 5
	local rampIn = math.max(settings.rampIn or 0, 0)
	local updateDirection = settings.updateDirection == true
	local directionResolver = settings.directionResolver

	local function resolveDirection(vec: Vector3): Vector3
		if lockHorizontal then
			vec = Vector3.new(vec.X, 0, vec.Z)
		end
		return vec.Magnitude > 0 and vec.Unit or Vector3.zero
	end

	local direction = resolveDirection(settings.direction or root.CFrame.LookVector)

	local function resolveVelocity(dir: Vector3, currentSpeed: number): Vector3
		local carried = dir * currentSpeed

		if influence <= 0 or not humanoid then
			return carried
		end

		local moveDirection = humanoid.MoveDirection
		if moveDirection.Magnitude <= 0 then
			return carried
		end

		return carried + resolveDirection(moveDirection) * humanoid.WalkSpeed * influence
	end

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

	local attachment = PhysicsService.ImpulseAttachment(root)
	if not attachment then return nil end

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = IMPULSE_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = maxForce
	velocity.VectorVelocity = resolveVelocity(direction, rampIn > 0 and 0 or speed)
	velocity:SetAttribute(IMPULSE_PRIORITY_ATTRIBUTE, priority)
	velocity.Parent = root

	local trove = Trove.new()

	trove:Add(tween)
	trove:Add(velocity)

	local facing = settings.facing
	local facingDirection = typeof(facing) == "Vector3" and Vector3.new(facing.X, 0, facing.Z) or nil

	if facingDirection and facingDirection.Magnitude > 0 then
		facingDirection = facingDirection.Unit

		local orientation = Instance.new("AlignOrientation")
		orientation.Name = FACING_NAME
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = attachment
		orientation.MaxTorque = settings.facingTorque or (mass * workspace.Gravity * 2500)
		orientation.Responsiveness = settings.facingResponsiveness or 100
		orientation.CFrame = CFrame.lookAt(root.Position, root.Position + facingDirection)
		orientation.Parent = root

		if humanoid then
			if humanoid:GetAttribute(AUTO_ROTATE_ATTRIBUTE) == nil then
				humanoid:SetAttribute(AUTO_ROTATE_ATTRIBUTE, humanoid.AutoRotate)
			end

			humanoid.AutoRotate = false
		end

		--@ Not troved directly: the constraint has to be gone before the AutoRotate check below,
		--@ and Trove does not order its cleanups.
		trove:Add(function()
			if orientation.Parent then
				orientation:Destroy()
			end

			if not humanoid or not humanoid.Parent then return end
			if PhysicsService.GetFacing(root) then return end

			local saved = humanoid:GetAttribute(AUTO_ROTATE_ATTRIBUTE)

			if saved ~= nil then
				humanoid.AutoRotate = saved
				humanoid:SetAttribute(AUTO_ROTATE_ATTRIBUTE, nil)
			end
		end)
	end

	local start = os.clock()

	local frameSignal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat

	trove:Add(frameSignal:Connect(function()
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

		local ramp = rampIn > 0 and math.min((os.clock() - start) / rampIn, 1) or 1

		velocity.VectorVelocity = resolveVelocity(currentDir, speedValue.Value * ramp)
	end))

	task.delay(duration, function()
		if velocity and velocity.Parent then
			velocity:Destroy()
		end
	end)

	return trove
end

function PhysicsService.ClearExistingImpulse(controller: {})
	if not controller then return end
	local character = controller.Character
	
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local existing = PhysicsService.GetImpulse(root)

	if existing then
		existing:Destroy()
	end

	local facing = PhysicsService.GetFacing(root)

	if facing then
		facing:Destroy()
	end
end

return PhysicsService