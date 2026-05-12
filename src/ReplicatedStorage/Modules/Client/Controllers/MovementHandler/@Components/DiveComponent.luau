--@ Diving
local DiveComponent = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

function DiveComponent:Activate(controller)
	local _character = controller.Character

	if not _character then
		return
	end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then
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

		_divetracks[_heldbind]:Play()
	end


	local _dive_speed = 60
	local _dive_duration = 1
	local _diveDirection = _heldbind
	local _trove = controller.Trove.new()

	local _directionOffsets = {
		["W"] = _humanoidRootPart.CFrame.LookVector,
		["S"] = -_humanoidRootPart.CFrame.LookVector,
		["A"] = -_humanoidRootPart.CFrame.RightVector,
		["D"] = _humanoidRootPart.CFrame.RightVector,
	}

	local _offset = _directionOffsets[_diveDirection]
	local _diveVelocity = (_directionOffsets[_diveDirection] * _dive_speed)
  
	warn("Dive Direction:", _diveDirection, "Offset:", _offset)

	local _camera = workspace.CurrentCamera
	local _baseCFrame = _humanoidRootPart.CFrame
	local _start = os.clock()

	local _velocity = Instance.new("BodyVelocity")
	_velocity.Name = "@impulse_velocity"
	
	_velocity.MaxForce = Vector3.new(_humanoidRootPart.AssemblyMass,
	 _humanoidRootPart.AssemblyMass, 
	 _humanoidRootPart.AssemblyMass) * Vector3.new(1, 0, 1) * 4e4

	_velocity.Velocity = _diveVelocity
	_velocity.Parent = _humanoidRootPart

	task.delay(_dive_duration, function()
		if _velocity and _velocity.Parent then
			_velocity:Destroy()
		end
	end)

	local speedMultiplier = Instance.new("NumberValue")
	speedMultiplier.Value = _dive_speed

	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(speedMultiplier, tweenInfo, {Value = 0})
	tween:Play()

	_trove:Add(tween)
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
			return 
		end

		_directionOffsets = {
			["W"] = _humanoidRootPart.CFrame.LookVector,
			["S"] = -_humanoidRootPart.CFrame.LookVector,
			["A"] = -_humanoidRootPart.CFrame.RightVector,
			["D"] = _humanoidRootPart.CFrame.RightVector,
		}

		_offset = _directionOffsets[_diveDirection]
		_diveVelocity = (_directionOffsets[_diveDirection] * speedMultiplier.Value)

		local _, camY = _camera.CFrame:ToOrientation()
		local targetCFrame = CFrame.new(_humanoidRootPart.Position) * CFrame.Angles(0, camY, 0)

		_humanoidRootPart.CFrame = targetCFrame
		_velocity.Velocity = _diveVelocity
	end))

	controller.StatusService:SetStatus(_character, "IsDiving", true, _dive_duration)

	DiveComponent:Deactivate(controller)
end

function DiveComponent:Deactivate(controller)
	local _character = controller.Character
	if not _character then return end

	if controller.StatusService:CheckStatuses(_character, { IsDiving = true }) then
		controller.StatusService:RemoveStatus(_character, "IsDiving")
	end
end

return DiveComponent
