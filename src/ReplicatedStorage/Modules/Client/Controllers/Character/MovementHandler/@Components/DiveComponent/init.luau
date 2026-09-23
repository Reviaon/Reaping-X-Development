--@ Diving
local RunService = game:GetService("RunService")

local Config = require(script.Config)

local DiveComponent = {}

local function planarDirection(cframe: CFrame, key: string): Vector3
	local axis = (key == "W" or key == "S") and cframe.LookVector or cframe.RightVector
	local sign = (key == "S" or key == "A") and -1 or 1

	return (Vector3.new(axis.X, 0, axis.Z) * sign).Unit
end

local function speedAt(startTime: number, elapsed: number): number
	local ramp = Config.Ramp

	if elapsed < startTime then
		local climb = (math.exp(ramp.Curve * elapsed / startTime) - 1) / (math.exp(ramp.Curve) - 1)
		return Config.Speed * (ramp.Floor + (1 - ramp.Floor) * climb)
	end

	local alpha = math.clamp((elapsed - startTime) / Config.Falloff, 0, 1)
	return Config.Speed * (1 - alpha)
end

local function faceCamera(root: BasePart): CFrame
	local _, yaw = workspace.CurrentCamera.CFrame:ToOrientation()
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)

	return root.CFrame
end

local function createVelocity(controller, root: BasePart): LinearVelocity
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = controller.PhysicsService.ImpulseName
	velocity:SetAttribute(controller.PhysicsService.ImpulsePriorityAttribute, Config.ImpulsePriority)

	velocity.Attachment0 = controller.PhysicsService.ImpulseAttachment(root)
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(1, 0, 1) * root.AssemblyMass * Config.ForcePerMass

	return velocity
end

local function isKnockedBack(controller, character)
	local recipe = controller.KnockbackService.Active(character)
	return recipe ~= nil and not recipe.steer and (recipe.priority or 0) >= Config.ImpulsePriority
end

local function isInterrupted(controller, character)
	return controller.StatusService:CheckStatuses(character, { IsStunned = true }) or isKnockedBack(controller, character)
end

local function clearImpulses(controller)
	if controller.CombatConfig then
		controller.CombatConfig:ClearImpulse(controller)
	else
		controller.PhysicsService.ClearExistingImpulse(controller)
	end
end

local function playVisual(controller, character, direction: string)
	controller.AttackService:BroadcastVisual(controller, {
		Effect = Config.Visual.Effect,
		Method = Config.Visual.Method,
		Info = { Character = character, Direction = direction },
	})
end

function DiveComponent:CanActivate(controller)
	local _character = controller.Character

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true, IsStunned = true }) then
		return false
	end

	if isKnockedBack(controller, _character) then
		return false
	end

	if controller.CooldownService:CheckCooldown(_character, "Dive") then
		return false
	end

	return true
end

function DiveComponent:Activate(controller)
	local _character = controller.Character
	if not _character or not DiveComponent:CanActivate(controller) then return end

	local _root = _character:FindFirstChild("HumanoidRootPart")
	if not _root then return end

	local _heldbind = controller.InputHandler:GetKeysDown(Config.Binds)
	if not _heldbind then return end

	local _direction = Config.BindAliases[_heldbind] or _heldbind
	local _settings = Config.Directions[_direction]
	local _startTime = _settings.StartTime

	local _isShiftLock = controller.StatusService:CheckStatuses(_character, { ShiftLock = true })
	local _isAttacking = controller.StatusService:CheckStatuses(_character, { IsAttacking = true })

	local _track = controller.AnimatorService:GetTrack(_character, _settings.Track)
	_track.Priority = Config.TrackPriority

	local _swingHolding = controller.AttackService:ReleaseSpentSwings(controller, Config.SwingReleaseFade)

	if not (_isAttacking and _swingHolding) then
		_track:Play()
	end

	local _trove = controller.Trove.new()
	local _lockedDirection = planarDirection(faceCamera(_root), _direction)
	local _velocity = createVelocity(controller, _root)
	local _start = os.clock()

	local function _clean()
		if _trove then
			_trove:Clean()
			_trove = nil
		end
	end

	local function _interrupt()
		_clean()
		_track:Stop(Config.StopFade)
		DiveComponent:Deactivate(controller)
	end

	clearImpulses(controller)

	_velocity.VectorVelocity = _lockedDirection * speedAt(_startTime, 0)
	_velocity.Parent = _root

	playVisual(controller, _character, _direction)

	task.delay(_startTime + Config.Duration, function()
		if _velocity.Parent then
			_velocity:Destroy()
		end
	end)

	_trove:Add(_velocity)

	_trove:Add(RunService.RenderStepped:Connect(function()
		local _elapsed = os.clock() - _start

		if _elapsed > _startTime + Config.Duration + Config.CleanupGrace then
			_clean()
			return
		end

		if isInterrupted(controller, _character) then
			_interrupt()
			return
		end

		local _speed = speedAt(_startTime, _elapsed)

		--@ Only on the way down: the ramp itself starts below the cutoff
		if _elapsed >= _startTime and _speed <= Config.CutoffSpeed and _velocity.Parent then
			_velocity:Destroy()
		end

		if not _isShiftLock or controller.StatusService:CheckStatuses(_character, { IsSprinting = true }) then
			faceCamera(_root)
		end

		if _velocity.Parent then
			_velocity.VectorVelocity = planarDirection(_root.CFrame, _direction) * _speed
		end
	end))

	local _statusDuration = Config.Duration * Config.StatusShare

	controller.StatusService:SetStatus(_character, "IsDiving", true, _statusDuration)
	controller.StatusService:SetStatus(_character, "DiveDirection", _direction, _statusDuration)
	controller.CooldownService:ApplyCooldown(_character, "Dive", Config.Cooldown)
end

function DiveComponent:Deactivate(controller)
	local _character = controller.Character
	if not _character then return end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then
		controller.StatusService:RemoveStatus(_character, "IsDiving")
		controller.StatusService:RemoveStatus(_character, "DiveDirection")
	end
end

return DiveComponent
