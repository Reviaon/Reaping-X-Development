--@ Diving
local DiveComponent = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--@ TODO: Replace Cooldown Handling -> Avoid hardcoded cooldown
local DIVE_COOLDOWN = 1.5 --@ Temporary
local _trove 

function DiveComponent:Activate(controller)
	local _character = controller.Character

	if not _character then
		return
	end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true, IsAttacking = true }) then
		return
	end

	if controller.CooldownService:CheckCooldown(_character, "Dive") then
		return
	end

	local _humanoidRootPart = _character:FindFirstChild("HumanoidRootPart")

	if not _humanoidRootPart then 
		return 
	end

	local _checkbinds = controller.InputHandler:AreKeysDown({"W","A","S","D","Q"})
	local _heldbind = controller.InputHandler:GetKeysDown({"W","A","S","D","Q"}) 
	local _isShiftLock = controller.StatusService:CheckStatuses(_character, { ShiftLock = true })

	if not _checkbinds then
		return
	end

	local _divetracks = {
		["W"] = controller.AnimatorService:GetTrack(_character, "DiveForward"), --@ Omni Directional Route
		["A"] = controller.AnimatorService:GetTrack(_character, "DiveLeft"),
		["S"] = controller.AnimatorService:GetTrack(_character, "DiveBackward"),
		["D"] = controller.AnimatorService:GetTrack(_character, "DiveRight")
	}

	if _checkbinds then
		if _heldbind ==  "Q" then 
			_heldbind = "W"
		 end

		_divetracks[_heldbind].Priority = Enum.AnimationPriority.Action2
		_divetracks[_heldbind]:Play()
	end

	--@ TODO: Refactor Dive Settings To be more dynamic and less hardcoded.
	local _dive_speed = 60
	local _dive_duration = 1
	local _diveDirection = _heldbind
	 _trove = controller.Trove.new()

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

	local speedMultiplier = Instance.new("NumberValue")
	speedMultiplier.Value = _dive_speed

	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(speedMultiplier, tweenInfo, {Value = 0})
	tween:Play()

	local _velocity = Instance.new("BodyVelocity")
	_velocity.Name = "@impulse_velocity"

	_velocity.MaxForce = Vector3.new(
		_humanoidRootPart.AssemblyMass,
		_humanoidRootPart.AssemblyMass,
		_humanoidRootPart.AssemblyMass
	) * Vector3.new(1, 0, 1) * 4e4

	_velocity.Velocity = _lockedDirection * speedMultiplier.Value
	_velocity.Parent = _humanoidRootPart

	task.delay(_dive_duration, function()
		if _velocity and _velocity.Parent then
			_velocity:Destroy()
		end
	end)


	_trove:Add(tween)
	_trove:Add(_velocity)
	
	_trove:Add(RunService.RenderStepped:Connect(function()
		if os.clock() - _start > (_dive_duration + 0.5) then
			_trove:Clean()
			_trove = nil
			return
		end

		if speedMultiplier.Value <= 10 then
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

			_velocity.Velocity = currentDirection * speedMultiplier.Value
		end
	end))

	controller.StatusService:SetStatus(_character, "IsDiving", true, _dive_duration / 2 )
	controller.CooldownService:ApplyCooldown(_character, "Dive", DIVE_COOLDOWN)
end

function DiveComponent:Deactivate(controller)
	local _character = controller.Character
	if not _character then return end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then
		controller.StatusService:RemoveStatus(_character, "IsDiving")
	end
end

return DiveComponent
