local Jloader = require("@game/ReplicatedStorage/JLoader")
local CameraHandler = Jloader.CreateHandler({Name = script.Name})
CameraHandler.Morphs = true

--@ Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--@ Modules
local GlobalFunctions = Jloader.GlobalFunctions
local Spring = GlobalFunctions.Spring
local InputHandler = GlobalFunctions.InputHandler
local MouseModule = GlobalFunctions.MouseModule
local ClientController = GlobalFunctions.ClientController
local ShakeLibrary = require("@game/ReplicatedStorage/Libraries/CameraLibrary/ShakeLibrary")
local DynamicLibrary = require("@game/ReplicatedStorage/Libraries/CameraLibrary/DynamicLibrary")

--@ Constants
local Camera = Workspace.CurrentCamera

local SHIFT_LOCK_OFFSET = Vector3.new(2, 0, 0)
local SHIFT_LOCK_ON_SPAWN = true --@ Every spawn starts in this state; LeftControl still toggles it
local MOUSE_OBJECT = nil

local TRANSITION_IN_SPEED = 60
local TRANSITION_OUT_SPEED = 30

local ROTATION_SPEED = 20
local USE_SMOOTH_ROTATION = false
local USE_DYNAMIC_INFLUENCE = false

--@ Dynamic camera offset (drift) — tune to taste.
local ORIGIN_FOLLOW_SPEED = 20 --@ how fast the origin part catches up to the torso (lower = more drift)
local DRIFT_STRENGTH = 0.4 --@ fraction of the origin's lag applied as camera drift
local DRIFT_MAX = 2 --@ max drift magnitude, in studs

local INFLUENCE_FLOOR = 0.2
local INFLUENCE_BLEND = 6
local _influenceLevel = INFLUENCE_FLOOR

local SUBJECT_HEIGHT_OFFSET = 1.5 --@ Torso subject sits at chest level; raise to the Humanoid subject's default head-level POV

--@ Springs
CameraHandler.cameraOffsetSpring = Spring.new(Vector3.zero)
CameraHandler.cameraOffsetSpring.Damper = 1

local shakeSpring = Spring.new(Vector3.zero)
shakeSpring.Damper = 0.8
shakeSpring.Speed = 40

local function punchSpring()
	local spring = Spring.new(0)
	spring.Speed = DynamicLibrary.Punch.Speed
	spring.Damper = DynamicLibrary.Punch.Damper
	return spring
end

local punchFov = punchSpring()
local punchRoll = punchSpring()

local sceneFov = Spring.new(0)
sceneFov.Speed = DynamicLibrary.FovSpeed
sceneFov.Damper = 1

local kickFov = Spring.new(0)
kickFov.Speed = DynamicLibrary.Kick.RiseSpeed
kickFov.Damper = 1

local heldFov = Spring.new(0)
heldFov.Speed = DynamicLibrary.HoldFovSpeed
heldFov.Damper = 1

local fovHolds = {}

local kickToken = 0

local swayOffset = Spring.new(Vector3.zero)
swayOffset.Speed = DynamicLibrary.Sway.Speed
swayOffset.Damper = DynamicLibrary.Sway.Damper

local swayRoll = Spring.new(0)
swayRoll.Speed = DynamicLibrary.Sway.Speed
swayRoll.Damper = DynamicLibrary.Sway.Damper

local sceneProfiles = {}
local activeProfile = nil
local activePartner = nil
local markerConnections = {}
local lastMarkerAt = 0

--@ Components
CameraHandler.components = {};

CameraHandler.components = Jloader.GlobalFunctions.Components.Load(script)

--@ State
local shiftLockEnabled = false
local inputConnections = {};

local inputActions = {
	Morphs = true,
	Began = {
		[Enum.KeyCode.LeftControl] = {
			canHold = false,
			action = function(controller)
				CameraHandler:ToggleShiftLock(not shiftLockEnabled, controller)
			end,
		} 
	},
	Ended = {

	}
}

function CameraHandler:Init()
	InputHandler.Init();
	InputHandler.BindInput(inputActions, inputConnections, ClientController);
end

local originCache = nil

local function getOriginCache()
	if originCache then
		return originCache
	end

	local template = Instance.new("Part")
	template.Name = "CameraOrigin"
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Transparency = 1
	template.Size = Vector3.new(1, 1, 1)

	originCache = GlobalFunctions.PartCache.new(template, 2)
	template:Destroy()

	return originCache
end

local function getTorso(Character)
	return Character
		and (
			Character:FindFirstChild("Torso")
			or Character:FindFirstChild("UpperTorso")
			or Character:FindFirstChild("HumanoidRootPart")
		)
end

local function unwatchMarkers()
	for _, connection in markerConnections do
		connection:Disconnect()
	end

	table.clear(markerConnections)
end

local function watchMarkers(characters: { Model }, scene)
	unwatchMarkers()

	if not scene.Marker then return end

	local function onMarker()
		local now = os.clock()
		if now - lastMarkerAt < scene.MarkerSpacing then return end

		lastMarkerAt = now
		CameraHandler:Shake(scene.MarkerShake)
	end

	local function watchTrack(track: AnimationTrack)
		table.insert(markerConnections, track:GetMarkerReachedSignal(scene.Marker):Connect(onMarker))
	end

	for _, character in characters do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then continue end

		for _, track in animator:GetPlayingAnimationTracks() do
			watchTrack(track)
		end

		table.insert(markerConnections, animator.AnimationPlayed:Connect(watchTrack))
	end
end

function CameraHandler:CreateCameraObject(controller)

	if controller._camera_origin then
		getOriginCache():ReturnPart(controller._camera_origin)
		controller._camera_origin = nil
	end

	local _camera_origin = getOriginCache():GetPart()
	controller._camera_origin = _camera_origin

	local torso = getTorso(controller.Character)

	if torso then
		_camera_origin.CFrame = torso.CFrame
	end

	return _camera_origin
end

function CameraHandler:InitCharacter(controller)
	local Character = controller.Character	

	if not Character then return warn("@CHARACTER FAILED TO LOAD") end

	--@ Tear down any loop/pooled part left over from a previous character.
	CameraHandler:Cleanup(controller)

	local _humanoid = Character:WaitForChild("Humanoid")
	Character:WaitForChild("HumanoidRootPart")

	local _trove = controller.Trove.new()
	controller._camera_trove = _trove

	local _mouse = MouseModule.new()

	MOUSE_OBJECT = _mouse
	MOUSE_OBJECT.filterDescendants = {Character, workspace.World.Visuals, workspace.World.Live}

	CameraHandler:ToggleShiftLock(SHIFT_LOCK_ON_SPAWN, controller)
	CameraHandler:CreateCameraObject(controller)

	_trove:Add(_humanoid.Died:Connect(function()
		if controller.Character ~= Character then return end

		CameraHandler:OnCharacterRemoved(controller)
	end))

	_trove:BindToRenderStep("CameraOriginUpdate", Enum.RenderPriority.Camera.Value - 1, function(DeltaTime: number)
		CameraHandler:UpdateOrigin(DeltaTime, controller)
	end)

	_trove:BindToRenderStep("CameraOffsetUpdate", Enum.RenderPriority.Camera.Value + 2, function(DeltaTime: number)
		CameraHandler:UpdateCamera(DeltaTime, controller)
	end)
end


--@ Release the per-character render loop and return the pooled origin part.
function CameraHandler:Cleanup(controller)
	_influenceLevel = INFLUENCE_FLOOR
	controller._camera_world_lag = nil

	activeProfile = nil
	activePartner = nil
	unwatchMarkers()

	kickToken += 1

	table.clear(fovHolds)

	for _, spring in { punchFov, punchRoll, sceneFov, swayRoll, kickFov, heldFov } do
		spring.Target = 0
		spring.Position = 0
		spring.Velocity = 0
	end

	swayOffset.Target = Vector3.zero
	swayOffset.Position = Vector3.zero
	swayOffset.Velocity = Vector3.zero

	if Camera then
		Camera.FieldOfView = DynamicLibrary.BaseFov
	end

	if controller._camera_trove then
		controller._camera_trove:Destroy()
		controller._camera_trove = nil
	end

	if controller._camera_origin then
		if Camera and Camera.CameraSubject == controller._camera_origin then
			Camera.CameraSubject = controller.Character and controller.Character:FindFirstChildOfClass("Humanoid")
		end
		getOriginCache():ReturnPart(controller._camera_origin)
		controller._camera_origin = nil
	end
end

function CameraHandler:OnCharacterRemoved(controller)
	CameraHandler:ToggleShiftLock(false, controller)
	CameraHandler:Cleanup(controller)
end

function CameraHandler:ShakeCamera(power, decay, amplifier)
	power = math.max(math.floor(tonumber(power) or 1), 1)
	amplifier = tonumber(amplifier) or 1

	shakeSpring.Position += Vector3.new(
		math.random(-power, power) * amplifier,
		math.random(-power, power) * amplifier,
		math.random(-power, power) * amplifier
	)

	shakeSpring.Damper = decay or 0.8
end

--@ A named shape from ShakeLibrary; scale multiplies its Amplifier for a one-off stronger or weaker knock.
function CameraHandler:Shake(name: string, scale: number?)
	local shape = ShakeLibrary.Enabled and ShakeLibrary.Shapes[name]
	if not shape then return end

	CameraHandler:ShakeCamera(
		ShakeLibrary.Steps,
		tonumber(shape.Damper) or 0.8,
		(tonumber(shape.Amplifier) or 0) * (scale or 1)
	)
end

function CameraHandler:Punch(name: string, scale: number?)
	local shape = DynamicLibrary.Punch.Shapes[name]
	if not shape then return end

	scale = scale or 1

	punchFov.Position += (shape.Fov or 0) * scale
	punchRoll.Position += (shape.Roll or 0) * scale * (math.random() < 0.5 and -1 or 1)
end

function CameraHandler:HoldFov(key: any, fov: number?)
	fovHolds[key] = fov

	local total = 0

	for _, held in fovHolds do
		total += held
	end

	heldFov.Target = total
end

function CameraHandler:Kick(name: string)
	local shape = DynamicLibrary.Kick.Shapes[name]
	if not shape then return end

	kickToken += 1
	local token = kickToken

	kickFov.Speed = DynamicLibrary.Kick.RiseSpeed
	kickFov.Target = shape.Fov

	task.delay(shape.Hold, function()
		if token ~= kickToken then return end

		kickFov.Speed = DynamicLibrary.Kick.SettleSpeed
		kickFov.Target = 0
	end)
end

local function sceneProfile(name: string?)
	local key = name or ""
	local cached = sceneProfiles[key]
	if cached then return cached end

	local profile = table.clone(DynamicLibrary.Scene)

	for field, value in (name and DynamicLibrary.Scenes[name]) or {} do
		profile[field] = value
	end

	sceneProfiles[key] = profile
	return profile
end

local function findFocus(controller): (Model?, {}?)
	local partner, name = controller.PairSceneService.PartnerOf(controller.Character)

	if partner and getTorso(partner) then
		return partner, sceneProfile(name)
	end

	return nil, nil
end

local function swayTarget(controller): (Vector3, number)
	local sway = DynamicLibrary.Sway
	local character = controller.Character
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")

	if activeProfile or not root or not torso then return Vector3.zero, 0 end
	if not controller.StatusService:CheckStatuses(character, sway.Statuses) then return Vector3.zero, 0 end

	local joint = root:FindFirstChild("RootJoint") or torso:FindFirstChild("Root")
	local rest = if joint and joint:IsA("Motor6D") and joint.Part0 then joint.Part0.CFrame * joint.C0 * joint.C1:Inverse() else root.CFrame
	local travel = Camera.CFrame:VectorToObjectSpace(torso.Position - rest.Position)
	local offset = Vector3.new(travel.X * sway.Share, travel.Y * sway.Share, travel.Z * sway.Depth)

	if offset.Magnitude > sway.MaxOffset then
		offset = offset.Unit * sway.MaxOffset
	end

	return offset, math.clamp(-travel.X * sway.Roll, -sway.MaxRoll, sway.MaxRoll)
end

function CameraHandler:ToggleShiftLock(state, controller)
	local Character = controller.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if state and not (Humanoid and HumanoidRootPart) then return end

	shiftLockEnabled = state
	UserInputService.MouseBehavior = state and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	CameraHandler.cameraOffsetSpring.Speed = state and TRANSITION_IN_SPEED or TRANSITION_OUT_SPEED
	CameraHandler.cameraOffsetSpring.Target = state and SHIFT_LOCK_OFFSET or Vector3.zero

	if state then
		controller.StatusService:SetStatus(Character, 
			"ShiftLock", 
			state
		)

		RunService:BindToRenderStep("ShiftLockRotation", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not (Character.Parent and HumanoidRootPart.Parent) then return end

			if not controller.StatusService:CheckStatuses(Character, {NoRotate = true, IsRagdolled = true, InPairScene = true})
				and not (controller.StatusService:CheckStatuses(Character, {IsSprinting = true}) 
				and not controller.StatusService:CheckStatuses(Character, {IsAttacking = true})) then

				Humanoid.AutoRotate = false
				
				local rootPos = HumanoidRootPart.Position
				local targetCFrame
	
				local _, camY = Camera.CFrame:ToOrientation()
				targetCFrame = CFrame.new(rootPos) * CFrame.Angles(0, camY, 0)
				
				if USE_SMOOTH_ROTATION then
					_, camY = Camera.CFrame:ToOrientation()
					targetCFrame = CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, camY, 0)	
					HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(targetCFrame, math.min(1, dt * ROTATION_SPEED * 2))		
				else
					HumanoidRootPart.CFrame = targetCFrame	
				end	
			else
				Humanoid.AutoRotate = true
			end
		end)
	else
		RunService:UnbindFromRenderStep("ShiftLockRotation")

		if Character then
			controller.StatusService:SetStatus(Character,
				"ShiftLock",
				nil
			)
		end

		if Humanoid then
			Humanoid.AutoRotate = true
		end
	end
end

function CameraHandler:IsShiftLockEnabled()
	return shiftLockEnabled
end

function CameraHandler:UpdateOrigin(DeltaTime, controller)
	local origin = controller._camera_origin
	local Character = controller.Character

	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

	if not (origin and Character and Humanoid) then
		controller._camera_world_lag = Vector3.zero
		return
	end

	local torso = getTorso(Character)
	if not torso then
		controller._camera_world_lag = Vector3.zero
		return
	end

	local status = controller.StatusService
	local root = Character:FindFirstChild("HumanoidRootPart") or torso
	local partner, profile = findFocus(controller)
	local previous = activeProfile

	if profile ~= previous or partner ~= activePartner then
		activeProfile = profile
		activePartner = partner
		sceneFov.Speed = if profile then DynamicLibrary.FovSpeed else DynamicLibrary.ReturnFovSpeed

		if profile then
			watchMarkers({ Character, partner }, profile)
		else
			unwatchMarkers()
		end

		if profile and not previous and profile.EnterPunch then
			CameraHandler:Punch(profile.EnterPunch)
		end
	end

	local height = Vector3.new(0, DynamicLibrary.Height, 0)
	local home = root.Position + height
	local target = home

	if partner then
		target = torso.Position:Lerp(getTorso(partner).Position, profile.Blend) + height
	end

	local returning = Camera.CameraSubject == origin and (origin.Position - home).Magnitude > DynamicLibrary.SettleDistance
	local onOrigin = profile ~= nil or returning
	local followSpeed = if profile then profile.FollowSpeed elseif returning then DynamicLibrary.ReturnSpeed else ORIGIN_FOLLOW_SPEED

	local gated = Humanoid.FloorMaterial ~= Enum.Material.Air
		and (
			status:CheckStatuses(Character, { IsAttacking = true })
			or status:CheckStatuses(Character, { IsCrouching = true })
			or status:CheckStatuses(Character, { DiveDirection = "S" })
		)

	_influenceLevel = _influenceLevel + ((gated and 1 or INFLUENCE_FLOOR) - _influenceLevel) * math.min(1, DeltaTime * INFLUENCE_BLEND)

	origin.CFrame = origin.CFrame:Lerp(CFrame.new(target), math.min(1, DeltaTime * followSpeed))

	local subject = if onOrigin then origin elseif USE_DYNAMIC_INFLUENCE then torso else Humanoid

	if Camera and Camera.CameraSubject ~= subject then
		Camera.CameraSubject = subject
	end

	controller._camera_world_lag = home - origin.Position
end

function CameraHandler:UpdateCamera(DeltaTime, controller)
	if not (Camera and controller.Character) then
		return
	end

	local drift = Vector3.zero
	local worldLag = controller._camera_world_lag

	if worldLag and USE_DYNAMIC_INFLUENCE then
		local localLag = Camera.CFrame:VectorToObjectSpace(worldLag) * DRIFT_STRENGTH * _influenceLevel
		drift = Vector3.new(localLag.X, localLag.Y, 0)

		if drift.Magnitude > DRIFT_MAX then
			drift = drift.Unit * DRIFT_MAX
		end
	end

	sceneFov.Target = activeProfile and activeProfile.Fov or 0

	local swayTo, rollTo = swayTarget(controller)

	swayOffset.Target = swayTo
	swayRoll.Target = rollTo

	local totalOffset = CameraHandler.cameraOffsetSpring.Position + shakeSpring.Position + drift + swayOffset.Position

	Camera.CFrame = Camera.CFrame
		* CFrame.new(totalOffset)
		* CFrame.Angles(0, 0, math.rad(punchRoll.Position + swayRoll.Position))
		+ Vector3.new(0, USE_DYNAMIC_INFLUENCE and SUBJECT_HEIGHT_OFFSET or 0, 0)

	Camera.FieldOfView = DynamicLibrary.BaseFov + sceneFov.Position + punchFov.Position + kickFov.Position + heldFov.Position
end

return CameraHandler
