--@ Diving
local RunService = game:GetService("RunService")

local Config = require(script.Config)

local DiveComponent = {}

local function planarDirection(cframe: CFrame, key: string): Vector3
	local axis = (key == "W" or key == "S") and cframe.LookVector or cframe.RightVector
	local sign = (key == "S" or key == "A") and -1 or 1

	return (Vector3.new(axis.X, 0, axis.Z) * sign).Unit
end

local function speedAt(startTime: number, elapsed: number, carry: number, falloff: number): number
	local ramp = Config.Ramp
	local peak = math.max(Config.Speed, carry)

	if elapsed < startTime then
		local floor = math.max(peak * ramp.Floor, carry)
		local climb = (math.exp(ramp.Curve * elapsed / startTime) - 1) / (math.exp(ramp.Curve) - 1)
		return floor + (peak - floor) * climb
	end

	local alpha = math.clamp((elapsed - startTime) / falloff, 0, 1)
	return carry + (peak - carry) * (1 - alpha)
end

local function rampDistance(startTime: number, carry: number): number
	local ramp = Config.Ramp
	local peak = math.max(Config.Speed, carry)
	local floor = math.max(peak * ramp.Floor, carry)
	local share = ((math.exp(ramp.Curve) - 1) / ramp.Curve - 1) / (math.exp(ramp.Curve) - 1)

	return startTime * (floor + (peak - floor) * share)
end

local function falloffDistance(falloff: number, carry: number): number
	local peak = math.max(Config.Speed, carry)
	local cutoff = math.max(Config.CutoffSpeed, carry)
	if peak <= cutoff then return 0 end

	return falloff * (peak - cutoff) / (peak - carry) * (peak + cutoff) / 2
end

--@ Shortens the falloff so a dive carrying momentum covers the standing dive's distance plus bonus
local function falloffFor(startTime: number, carry: number, bonus: number): number
	if carry <= 0 and bonus <= 0 then return Config.Falloff end

	local peak = math.max(Config.Speed, carry)
	local cutoff = math.max(Config.CutoffSpeed, carry)
	if peak <= cutoff then return Config.Falloff end

	local target = rampDistance(startTime, 0) + falloffDistance(Config.Falloff, 0) + bonus
	local remaining = target - rampDistance(startTime, carry)
	local falloff = 2 * remaining / (peak + cutoff) * (peak - carry) / (peak - cutoff)

	return math.clamp(falloff, Config.Momentum.MinFalloff, Config.Falloff)
end

local function carriedSpeed(root: BasePart, direction: Vector3): number
	local planar = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	return math.max(0, planar:Dot(direction)) * Config.Momentum.Carry
end

local function turnToward(current: Vector3, target: Vector3, dt: number): Vector3
	local alpha = 1 - math.exp(-Config.SprintTurnRate * dt)
	local from = CFrame.lookAt(Vector3.zero, current)
	local to = CFrame.lookAt(Vector3.zero, target)
	local turned = from:Lerp(to, alpha).LookVector * Vector3.new(1, 0, 1)

	return turned.Magnitude > 1e-3 and turned.Unit or target
end

local function faceCamera(root: BasePart): CFrame
	local _, yaw = workspace.CurrentCamera.CFrame:ToOrientation()
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)

	return root.CFrame
end

local function faceDirection(root: BasePart, direction: Vector3): CFrame
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)

	return root.CFrame
end

local function runDirection(character: Model, root: BasePart): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid and humanoid.MoveDirection * Vector3.new(1, 0, 1)

	if moving and moving.Magnitude > 1e-3 then
		return moving.Unit
	end

	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
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

	if not _character then
		return false
	end

	if controller.StatusService:CheckStatuses(_character, { 
		IsDiving = true, 
		IsStunned = true,
		IsRagdolled = true,
		}) then
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
	
	if not DiveComponent:CanActivate(controller) then 
		return 
	end

	local _root = _character:FindFirstChild("HumanoidRootPart")
	if not _root then return end

	local _heldbind = controller.InputHandler:GetKeysDown(Config.Binds)
	if not _heldbind then return end

	local _isSprinting = controller.StatusService:CheckStatuses(_character, { IsSprinting = true })
	local _direction = _isSprinting and Config.SprintDirection or Config.BindAliases[_heldbind] or _heldbind
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
	local _runDirection = _isSprinting and runDirection(_character, _root) or nil
	local _facing = if _runDirection then faceDirection(_root, _runDirection) else faceCamera(_root)
	local _lockedDirection = planarDirection(_facing, _direction)
	local _carry = carriedSpeed(_root, _lockedDirection)
	local _falloff = falloffFor(_startTime, _carry, _isSprinting and Config.Momentum.SprintBonus or 0)
	local _sprintDive = _runDirection ~= nil
	local _steering = _sprintDive
	local _velocity = createVelocity(controller, _root)
	local _start = os.clock()

	local function _releaseFacing()
		if _runDirection then
			_runDirection = nil
			controller.StatusService:RemoveStatus(_character, "NoRotate", Config.FacingSource)
		end
	end

	local function _clean()
		_releaseFacing()

		if _trove then
			_trove:Clean()
			_trove = nil
		end
	end

	if _runDirection then
		controller.StatusService:SetStatus(_character, "NoRotate", true, nil, Config.FacingSource)
	end

	local function _interrupt()
		_clean()
		_track:Stop(Config.StopFade)
		DiveComponent:Deactivate(controller)
	end

	clearImpulses(controller)
	controller.AttackService:ReportDive(controller)

	_velocity.VectorVelocity = _lockedDirection * speedAt(_startTime, 0, _carry, _falloff)
	_velocity.Parent = _root

	playVisual(controller, _character, _direction)

	task.delay(_startTime + Config.Duration, function()
		if _velocity.Parent then
			_velocity:Destroy()
		end
	end)

	_trove:Add(_velocity)

	_trove:Add(RunService.RenderStepped:Connect(function(dt)
		local _elapsed = os.clock() - _start

		if _elapsed > _startTime + Config.Duration + Config.CleanupGrace then
			_clean()
			return
		end

		if isInterrupted(controller, _character) then
			_interrupt()
			return
		end

		local _speed = speedAt(_startTime, _elapsed, _carry, _falloff)

		--@ Only on the way down: the ramp itself starts below the cutoff
		if _elapsed >= _startTime and _speed <= math.max(Config.CutoffSpeed, _carry) and _velocity.Parent then
			_velocity:Destroy()
			_releaseFacing()
		end

		if _sprintDive then
			if _runDirection then
				_steering = _steering and controller.StatusService:CheckStatuses(_character, { IsSprinting = true })

				if _steering then
					_runDirection = turnToward(_runDirection, runDirection(_character, _root), dt)
				end

				faceDirection(_root, _runDirection)
			end
		elseif not _isShiftLock or controller.StatusService:CheckStatuses(_character, { IsSprinting = true }) then
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
