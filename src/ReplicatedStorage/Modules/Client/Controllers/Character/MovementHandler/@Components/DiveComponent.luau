--@ Diving
local DiveComponent = {} 

local RunService = game:GetService("RunService")

--@ TODO: Replace Cooldown Handling -> Avoid hardcoded cooldown
local DIVE_COOLDOWN = 1.5 --@ Temporary

--@ Dash momentum outranks attack impulses, so a lower-priority impulse landing
--  mid-dash is ignored instead of stomping it.
local DIVE_IMPULSE_PRIORITY = 2

local DIVE_RAMP_FLOOR = 0.15
local DIVE_RAMP_CURVE = 4
local DIVE_FALLOFF = 0.8
local DIVE_CUTOFF_SPEED = 10

local function isKnockedBack(controller, character)
	local recipe = controller.KnockbackService.Active(character)
	return recipe ~= nil and not recipe.steer and (recipe.priority or 0) >= DIVE_IMPULSE_PRIORITY
end

local function isInterrupted(controller, character)
	return controller.StatusService:CheckStatuses(character, { IsStunned = true }) or isKnockedBack(controller, character)
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

	if not _character then
		return
	end
	
	if not DiveComponent:CanActivate(controller) then
		return
	end
	
	local _humanoidRootPart = _character:FindFirstChild("HumanoidRootPart")

	if not _humanoidRootPart then 
		return 
	end

	local _checkbinds = controller.InputHandler:AreKeysDown({"W","A","S","D","Q"})
	local _heldbind = controller.InputHandler:GetKeysDown({"W","A","S","D","Q"}) 
	local _isShiftLock = controller.StatusService:CheckStatuses(_character, { ShiftLock = true })
	local _isAttacking = controller.StatusService:CheckStatuses(_character, { IsAttacking = true })
	
	if not _checkbinds then
		return
	end

	local _divetracks = {
		["W"] = controller.AnimatorService:GetTrack(_character, "DiveForward"), --@ Omni Directional Route
		["A"] = controller.AnimatorService:GetTrack(_character, "DiveLeft"),
		["S"] = controller.AnimatorService:GetTrack(_character, "DiveBackward"),
		["D"] = controller.AnimatorService:GetTrack(_character, "DiveRight")
	}

	local _dive_start_times = {
		["W"] = 0.125,
		["A"] = 0.125,
		["S"] = 0.2,
		["D"] = 0.125
	}

	if _checkbinds then
		if _heldbind ==  "Q" then 
			_heldbind = "W"
		 end

		_divetracks[_heldbind].Priority = Enum.AnimationPriority.Action3

		local _swingHolding = controller.AttackService:ReleaseSpentSwings(controller, 0.1)

		if not (_isAttacking and _swingHolding) then
			_divetracks[_heldbind]:Play()
		end
	end

	--@ TODO: Refactor Dive Settings To be more dynamic and less hardcoded.
	local _dive_speed = 60
	local _dive_duration = 1
	local _diveDirection = _heldbind
	local _dive_start_time = _dive_start_times[_diveDirection] or 0
	
	local _trove = controller.Trove.new()

	local _directionOffsets = {
		["W"] = _humanoidRootPart.CFrame.LookVector,
		["S"] = -_humanoidRootPart.CFrame.LookVector,
		["A"] = -_humanoidRootPart.CFrame.RightVector,
		["D"] = _humanoidRootPart.CFrame.RightVector,
	}

	local _offset = _directionOffsets[_diveDirection]
	local _diveVelocity = (_directionOffsets[_diveDirection] * _dive_speed)
  
	local _camera = workspace.CurrentCamera
	local _startCFrame = _humanoidRootPart.CFrame

	local function _updateOrientation()
		local _, camY = _camera.CFrame:ToOrientation()
		local targetCFrame = CFrame.new(_humanoidRootPart.Position) * CFrame.Angles(0, camY, 0)
		_humanoidRootPart.CFrame = targetCFrame
		return targetCFrame
	end

	local _lockedDiveCFrame = _updateOrientation()

	local _lockedDirectionOffsets = {
		["W"] = _lockedDiveCFrame.LookVector,
		["S"] = -_lockedDiveCFrame.LookVector,
		["A"] = -_lockedDiveCFrame.RightVector,
		["D"] = _lockedDiveCFrame.RightVector,
	}

	local _lockedDirection = Vector3.new(
		_lockedDirectionOffsets[_diveDirection].X,
		0,
		_lockedDirectionOffsets[_diveDirection].Z
	).Unit

	local _start = os.clock()
	local _rampRange = math.exp(DIVE_RAMP_CURVE) - 1

	local function _speedAt(elapsed)
		if elapsed < _dive_start_time then
			local climb = (math.exp(DIVE_RAMP_CURVE * elapsed / _dive_start_time) - 1) / _rampRange
			return _dive_speed * (DIVE_RAMP_FLOOR + (1 - DIVE_RAMP_FLOOR) * climb)
		end

		local alpha = math.clamp((elapsed - _dive_start_time) / DIVE_FALLOFF, 0, 1)
		return _dive_speed * (1 - alpha)
	end

	local _velocity = Instance.new("LinearVelocity")
	_velocity.Name = controller.PhysicsService.ImpulseName
	_velocity:SetAttribute(controller.PhysicsService.ImpulsePriorityAttribute, DIVE_IMPULSE_PRIORITY)

	_velocity.Attachment0 = controller.PhysicsService.ImpulseAttachment(_humanoidRootPart)
	_velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	_velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	_velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	_velocity.MaxAxesForce = Vector3.new(
		_humanoidRootPart.AssemblyMass,
		_humanoidRootPart.AssemblyMass,
		_humanoidRootPart.AssemblyMass
	) * Vector3.new(1, 0, 1) * 4e4

	local function _interrupt()
		if _trove then
			_trove:Clean()
			_trove = nil
		end

		_divetracks[_diveDirection]:Stop(0.1)
		DiveComponent:Deactivate(controller)
	end

	if controller.CombatConfig then
		controller.CombatConfig:ClearImpulse(controller)
	else
		controller.PhysicsService.ClearExistingImpulse(controller)
	end

	_velocity.VectorVelocity = _lockedDirection * _speedAt(0)
	_velocity.Parent = _humanoidRootPart

	task.delay(_dive_start_time + _dive_duration, function()
		if _velocity and _velocity.Parent then
			_velocity:Destroy()
		end
	end)

	_trove:Add(_velocity)

	_trove:Add(RunService.RenderStepped:Connect(function()
		local _elapsed = os.clock() - _start

		if _elapsed > (_dive_start_time + _dive_duration + 0.5) then
			if _trove then
				_trove:Clean()
				_trove = nil
			end
			return
		end

		if isInterrupted(controller, _character) then
			_interrupt()
			return
		end

		local _speed = _speedAt(_elapsed)

		--@ Only on the way down: the ramp itself starts below the cutoff.
		if _elapsed >= _dive_start_time and _speed <= DIVE_CUTOFF_SPEED then
			if _velocity and _velocity.Parent then
				_velocity:Destroy()
			end
		end

		if not _isShiftLock or controller.StatusService:CheckStatuses(_character, { IsSprinting = true }) then
			_updateOrientation()
		end

		if _velocity and _velocity.Parent then

			local currentOffsets = {
				["W"] = _humanoidRootPart.CFrame.LookVector,
				["S"] = -_humanoidRootPart.CFrame.LookVector,
				["A"] = -_humanoidRootPart.CFrame.RightVector,
				["D"] = _humanoidRootPart.CFrame.RightVector,
			}

			local currentDirection = Vector3.new(
				currentOffsets[_diveDirection].X,
				0,
				currentOffsets[_diveDirection].Z
			).Unit

			_velocity.VectorVelocity = currentDirection * _speed
		end
	end))

	controller.StatusService:SetStatus(_character, "IsDiving", true, _dive_duration / 2 )
	controller.StatusService:SetStatus(_character, "DiveDirection", _heldbind, _dive_duration / 2 )
	controller.CooldownService:ApplyCooldown(_character, "Dive", DIVE_COOLDOWN)
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
