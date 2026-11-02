local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local TackleLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/TackleLibrary")

local TackleComponent = {
	KeepsScene = true,
}

local SCOPE = "Tackle"
local COOLDOWN = "Tackle"

local GROUNDED = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local warned = {}

local tackleRelay = nil
local onRejected = nil

local function getTackleRelay()
	if tackleRelay then return tackleRelay end

	tackleRelay = Jloader.GetService("TackleService")

	if tackleRelay then
		tackleRelay.Rejected:Connect(function(reason)
			if onRejected then
				onRejected(reason)
			end
		end)
	end

	return tackleRelay
end

local function loadTrack(controller, name: string): AnimationTrack?
	local character = controller.Character

	if controller.AnimatorService:HasAnimation(name) then
		local loaded, track = pcall(controller.AnimatorService.GetTrack, controller.AnimatorService, character, name)

		if loaded and track then
			track.Priority = TackleLibrary.TrackPriority
			track.Looped = false
			return track
		end
	end

	if not warned[name] then
		warned[name] = true
		warn(`[Tackle] "{name}" has no published animation yet; the tackle moves without it`)
	end

	return nil
end

local function flat(vector: Vector3): Vector3?
	local planar = vector * Vector3.new(1, 0, 1)

	return if planar.Magnitude > 1e-3 then planar.Unit else nil
end

local function turnToward(current: Vector3, target: Vector3, rate: number, dt: number): Vector3
	if rate <= 0 then return current end

	local alpha = 1 - math.exp(-rate * dt)
	local turned = CFrame.lookAt(Vector3.zero, current):Lerp(CFrame.lookAt(Vector3.zero, target), alpha).LookVector

	return flat(turned) or current
end

local function holdLastFrame(track: AnimationTrack?)
	if not track or not track.IsPlaying or track.Speed == 0 or track.Length <= 0 then return end

	if track.TimePosition >= track.Length - 1 / 30 then
		track:AdjustSpeed(0)
	end
end

local function isGrounded(humanoid: Humanoid): boolean
	return GROUNDED[humanoid:GetState()] == true or humanoid.FloorMaterial ~= Enum.Material.Air
end

local function isInterrupted(controller, character: Model, grabbing: boolean?): boolean
	if controller.StatusService:CheckStatuses(character, { IsStunned = true, IsRagdolled = true }) then
		return true
	end

	if not grabbing and controller.PairSceneService.IsInScene(character) then
		return true
	end

	local recipe = controller.KnockbackService.Active(character)
	return recipe ~= nil and not recipe.steer and (recipe.priority or 0) >= TackleLibrary.ImpulsePriority
end

local function variantFor(victim: CFrame, from: Vector3): string
	local look = flat(victim.LookVector)
	local toward = flat(from - victim.Position)

	if look and toward and look:Dot(toward) <= math.cos(math.rad(180 - TackleLibrary.BackArc / 2)) then
		return "Back"
	end

	return "Front"
end

local function isGrabbable(controller, target: Instance): boolean
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return false end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not target:FindFirstChild("HumanoidRootPart") then return false end

	return not controller.StatusService:IsHitImmune(target) and not controller.PairSceneService.IsInScene(target)
end

local function createVelocity(controller, root: BasePart): LinearVelocity
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = controller.PhysicsService.ImpulseName
	velocity:SetAttribute(controller.PhysicsService.ImpulsePriorityAttribute, TackleLibrary.ImpulsePriority)
	velocity.Attachment0 = controller.PhysicsService.ImpulseAttachment(root)
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(1, 0, 1) * root.AssemblyMass * TackleLibrary.ForcePerMass

	return velocity
end

local function createLift(controller, root: BasePart): VectorForce
	local lift = Instance.new("VectorForce")
	lift.Name = TackleLibrary.LiftName
	lift.Attachment0 = controller.PhysicsService.ImpulseAttachment(root)
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - TackleLibrary.Leap.Gravity), 0)

	return lift
end

local function createHitbox(controller, character: Model)
	local living = controller.AttackService:LivingFolder()
	if not living or not controller.CombatConfig then return nil end

	local hitbox = TackleLibrary.Hitbox
	local data = controller.CombatConfig:BuildHitboxData(hitbox)
	data.Attacker = character
	data.Debug = controller.DebugService.IsEnabled()

	return controller.HitboxService.New(hitbox.shape, data, { living }, { character })
end

local function faceAlong(root: BasePart, heading: Vector3)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + heading)
end

function TackleComponent:IsArmed(controller): boolean
	local character = controller.Character

	return character ~= nil and controller.StatusService:CheckStatuses(character, { [TackleLibrary.ArmedStatus] = true })
end

function TackleComponent:CanActivate(controller, _combatState): boolean
	local character = controller.Character
	if not character or not controller.HumanoidRootPart then return false end

	if not TackleComponent:IsArmed(controller) then return false end
	if controller.CooldownService:CheckCooldown(character, COOLDOWN) then return false end

	if controller.StatusService:CheckStatuses(character, {
		[TackleLibrary.Status] = true,
		IsRagdolled = true,
		IsDiving = true,
		IsBlocking = true,
		ComboLocked = true,
	}) or controller.StatusService:IsHitYielded(character) or controller.StatusService:IsActionLocked(character) then
		return false
	end

	return not isInterrupted(controller, character)
end

function TackleComponent:Activate(controller, combatState)
	if not TackleComponent:CanActivate(controller, combatState) then return end

	local character = controller.Character
	local humanoid = controller.Humanoid
	local root = controller.HumanoidRootPart
	local StatusService = controller.StatusService
	local leap, miss = TackleLibrary.Leap, TackleLibrary.Miss
	local grapple = nil
	local relay = getTackleRelay()

	local state = controller:Scope(SCOPE)
	local trove = controller.Trove.new()

	local heading = flat(humanoid.MoveDirection) or flat(root.CFrame.LookVector) or Vector3.zAxis
	local planar = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local launchSpeed = math.max(leap.Speed, planar:Dot(heading))
	local rise = math.min(math.max(root.AssemblyLinearVelocity.Y, 0) + leap.Lift, leap.MaxRise)

	local diveTrack = loadTrack(controller, TackleLibrary.Animations.Dive)
	local missTrack = nil

	local velocity = createVelocity(controller, root)
	local lift = createLift(controller, root)
	local hitbox = createHitbox(controller, character)

	local started = os.clock()
	local landedAt = nil
	local landingSpeed = 0
	local getUpAt = nil
	local scene = nil

	local function finish(fade: number)
		if state.trove ~= trove then return end

		state.trove = nil
		state.cancel = nil
		trove:Clean()

		if onRejected and state.rejecting == trove then
			onRejected = nil
			state.rejecting = nil
		end

		for _, track in { diveTrack, missTrack } do
			if track.IsPlaying then
				track:Stop(fade)
			end
		end

		if scene then
			scene:Stop(fade)
		end

		if character.Parent then
			StatusService:RemoveStatus(character, "NoRotate", TackleLibrary.FacingSource)
			StatusService:RemoveStatus(character, TackleLibrary.Status)
		end
	end

	if state.cancel then
		state.cancel(TackleLibrary.StopFade)
	end

	state.trove = trove
	state.cancel = finish

	trove:Add(velocity)
	trove:Add(lift)

	if hitbox then
		trove:Add(function()
			hitbox:Dispose()
		end)
	end

	if controller.CombatConfig then
		controller.CombatConfig:ClearImpulse(controller)
	else
		controller.PhysicsService.ClearExistingImpulse(controller)
	end

	faceAlong(root, heading)

	root.AssemblyLinearVelocity = heading * launchSpeed + Vector3.new(0, rise, 0)
	velocity.VectorVelocity = heading * launchSpeed
	velocity.Parent = root
	lift.Parent = root

	StatusService:SetStatus(character, TackleLibrary.Status, true, leap.MaxFlight + miss.SkidTime + miss.ProneHold + 3)
	StatusService:SetStatus(character, "NoRotate", true, nil, TackleLibrary.FacingSource)
	controller.CooldownService:ApplyCooldown(character, COOLDOWN, TackleLibrary.Cooldown)

	if relay then
		relay.ReportTackle:Fire()
	end

	if diveTrack then
		diveTrack:Play(TackleLibrary.TrackFade, 1, leap.TrackSpeed)
	end

	local function grab(target: Model)
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not relay or not targetRoot then return end

		local variant = variantFor(targetRoot.CFrame, root.Position)
		local definition = TackleLibrary.Grapples[variant]

		local predicted = controller.PairSceneService.Predict(character, definition, target)
		if not predicted then return end

		scene = predicted
		grapple = definition

		hitbox:Dispose()
		velocity:Destroy()
		lift:Destroy()

		if diveTrack and diveTrack.IsPlaying then
			diveTrack:Stop(grapple.IntroFade)
		end

		StatusService:SetStatus(character, TackleLibrary.Status, true)

		state.rejecting = trove
		onRejected = function(reason)
			if state.rejecting ~= trove then return end

			predicted:Reject(reason)

			if controller.DebugService.IsEnabled() then
				warn(`[Tackle] server rejected the grab on {target.Name}: {reason}`)
			end
		end

		relay.ReportHit:Fire(target, workspace:GetServerTimeNow(), variant)
	end

	local function land()
		landedAt = os.clock()
		landingSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude

		lift:Destroy()

		if hitbox then
			hitbox:Dispose()
		end

		missTrack = loadTrack(controller, TackleLibrary.Animations.Miss)

		if diveTrack and diveTrack.IsPlaying then
			diveTrack:Stop(TackleLibrary.TrackFade)
		end

		local length = 0

		if missTrack then
			missTrack:Play(TackleLibrary.TrackFade, 1, miss.TrackSpeed)
			length = missTrack.Length / miss.TrackSpeed
		end

		getUpAt = landedAt + math.max(length, miss.SkidTime) + miss.ProneHold
	end

	local function impact(target: Model)
		if not relay then return end

		relay.ReportHit:Fire(target, workspace:GetServerTimeNow(), TackleLibrary.Impact.Variant)

		land()
		landingSpeed *= TackleLibrary.Impact.SkidCarry
	end

	if hitbox then
		hitbox.onHit:Connect(function(target)
			if scene or landedAt or not isGrabbable(controller, target) then return end

			if controller.PairSceneService.Supports(target) then
				grab(target)
			else
				impact(target)
			end
		end)
	end

	trove:Add(RunService.RenderStepped:Connect(function(dt)
		if not root.Parent or humanoid.Health <= 0 or isInterrupted(controller, character, scene ~= nil) then
			finish(TackleLibrary.StopFade)
			return
		end

		local now = os.clock()

		if scene then
			if scene:State() == "ended" then
				finish(if scene.Confirmed then grapple.ReleaseFade else TackleLibrary.StopFade)
			end

			return
		end

		holdLastFrame(diveTrack)
		holdLastFrame(missTrack)

		if not landedAt then
			local flight = now - started

			if flight >= leap.MinFlight and isGrounded(humanoid) then
				land()
			elseif flight >= leap.MaxFlight then
				finish(TackleLibrary.StopFade)
				return
			else
				local held = flat(humanoid.MoveDirection)

				if held then
					heading = turnToward(heading, held, leap.SteerRate, dt)
				end

				local speed = leap.CruiseSpeed + (launchSpeed - leap.CruiseSpeed) * math.exp(-leap.Drag * flight)

				velocity.VectorVelocity = heading * speed
				faceAlong(root, heading)
				return
			end
		end

		local skid = (now - landedAt) / miss.SkidTime

		if skid < 1 then
			velocity.VectorVelocity = heading * landingSpeed * (1 - skid) ^ miss.SkidCurve
		elseif velocity.Parent then
			velocity:Destroy()
		end

		faceAlong(root, heading)

		if now >= getUpAt then
			finish(miss.GetUpFade)
		end
	end))

	trove:Add(humanoid.Died:Connect(function()
		finish(TackleLibrary.StopFade)
	end))
end

function TackleComponent:Deactivate(controller, _combatState)
	local state = controller:Scope(SCOPE)

	if state.cancel then
		state.cancel(TackleLibrary.StopFade)
	end
end

return TackleComponent
