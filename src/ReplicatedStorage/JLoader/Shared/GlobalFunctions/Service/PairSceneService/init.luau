local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatusService = require("./StatusService")
local AnimatorService = require("./AnimatorService")
local DebugService = require("./DebugService")
local TrajectoryService = require("./TrajectoryService")
local Signal = require("../Signal")

local Config = require("@self/Config")
local Placement = require("@self/Placement")
local Timeline = require("@self/Timeline")

local PairSceneService = {
	Settings = Config,
	Started = Signal.new(),
	Resolved = Signal.new(),
	Launched = Signal.new(),
	Struck = Signal.new(),

	Align = Placement.Align,
	Place = Placement.Place,
	Settled = Placement.Settled,
	MeasureBounds = Placement.MeasureBounds,
}

local IS_SERVER = RunService:IsServer()

local active = {}
local members = {}
local predictions = {}
local heldRoots = {}
local carries = {}
local carried = setmetatable({}, { __mode = "k" })
local heldFrames = setmetatable({}, { __mode = "k" })
local sceneTracks = setmetatable({}, { __mode = "k" })
local guards = {}
local followBones = setmetatable({}, { __mode = "k" })
local nextId = 0
local stepper = nil

local function rootOf(character: Instance?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function liveFolder(): Instance?
	local found = workspace

	for _, segment in Config.LivePath do
		found = found:FindFirstChild(segment)
		if not found then return nil end
	end

	return found
end

local function boneOf(model: Model, name: string): Bone?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Bone") then found else nil
end

local function shaken(character: Model, frame: CFrame, across: Vector3): CFrame
	local shake = character:GetAttribute(Config.FollowShakeAttribute)
	if typeof(shake) ~= "Vector3" then return frame end

	local t = workspace:GetServerTimeNow() % 1e4 * shake.Z
	local sway = math.noise(t, 1.3) * 2
	local twist = math.noise(t, 5.9) * 2
	local position = frame.Position + across * (sway * shake.Y)

	return CFrame.new(position) * CFrame.Angles(0, math.rad(shake.X) * twist, 0) * frame.Rotation
end

local function followFrame(character: Model, partner: Model?): CFrame?
	local boneName = character:GetAttribute(Config.FollowAttribute)
	local offset = character:GetAttribute(Config.FollowOffsetAttribute)

	if typeof(boneName) ~= "string" or typeof(offset) ~= "CFrame" or not partner then return nil end

	local partnerRoot = partner:FindFirstChild("HumanoidRootPart")
	if not partnerRoot then return nil end

	local bone = followBones[character]

	if not bone or bone.Name ~= boneName or not bone:IsDescendantOf(partner) then
		bone = boneOf(partner, boneName)
		followBones[character] = bone
	end

	if not bone then return nil end

	return shaken(character, bone.TransformedWorldCFrame * offset, partnerRoot.CFrame.RightVector)
end

local function startFollow(character: Model, partner: Model, follow): boolean
	local partnerRoot = partner:FindFirstChild("HumanoidRootPart")
	local bone = boneOf(partner, follow.Bone)

	if not partnerRoot or not bone then return false end

	local boneFrame = bone.TransformedWorldCFrame
	local held = (partnerRoot.CFrame.Rotation + boneFrame.Position) * (follow.Offset or CFrame.identity)
	local shake = follow.Shake

	character:SetAttribute(Config.FollowAttribute, follow.Bone)
	character:SetAttribute(Config.FollowOffsetAttribute, boneFrame:ToObjectSpace(held))

	if shake then
		character:SetAttribute(Config.FollowShakeAttribute, Vector3.new(shake.Angle or 0, shake.Offset or 0, shake.Frequency or 0))
	end

	return true
end

local function clearFollow(character: Model)
	followBones[character] = nil
	character:SetAttribute(Config.FollowAttribute, nil)
	character:SetAttribute(Config.FollowOffsetAttribute, nil)
	character:SetAttribute(Config.FollowShakeAttribute, nil)
end

local function anchorOf(character: Instance?): CFrame?
	local anchor = character and character:GetAttribute(Config.AnchorAttribute)
	return if typeof(anchor) == "CFrame" then anchor else nil
end

local function isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function hold(root: BasePart, anchor: CFrame)
	if not root.Anchored then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	end

	if root.CFrame ~= anchor then
		root.CFrame = anchor
	end
end

local function limbsOf(character: Model): { [Motor6D]: BasePart }
	local torso = character:FindFirstChild("Torso")
	local limbs = {}

	if not torso then return limbs end

	for _, name in Config.LooseJoints do
		local motor = torso:FindFirstChild(name)

		if motor and motor:IsA("Motor6D") and motor.Part1 then
			limbs[motor] = motor.Part1
		end
	end

	return limbs
end

local function torsoFrameOf(character: Model): CFrame?
	local root = rootOf(character)
	local rootJoint = root and root:FindFirstChild("RootJoint")
	if not rootJoint or not rootJoint:IsA("Motor6D") then return nil end

	return root.CFrame * rootJoint.C0 * rootJoint.C1:Inverse()
end

local function seat(limb: BasePart, motor: Motor6D, torsoFrame: CFrame, anchored: boolean)
	limb.Anchored = anchored
	limb.CFrame = torsoFrame * motor.C0 * motor.C1:Inverse()
	limb.AssemblyLinearVelocity = Vector3.zero
	limb.AssemblyAngularVelocity = Vector3.zero
end

local function seatLimbs(character: Model, anchored: boolean)
	local torsoFrame = torsoFrameOf(character)
	if not torsoFrame then return end

	for motor, limb in limbsOf(character) do
		seat(limb, motor, torsoFrame, anchored)
	end
end

local function loosen(character: Model)
	character:SetAttribute(Config.LooseAttribute, true)
	seatLimbs(character, true)
end

local function loosenLocally(character: Model)
	local torsoFrame = torsoFrameOf(character)
	if not torsoFrame then return end

	for motor, limb in limbsOf(character) do
		if limb.Anchored then
			seat(limb, motor, torsoFrame, false)
		else
			limb.CFrame += torsoFrame * motor.C0.Position - limb.CFrame * motor.C1.Position
		end
	end
end

local function place(character: Model, partner: Model)
	local root = rootOf(character)
	local followed = root and followFrame(character, partner)

	if followed then
		root.CFrame = followed
	end
end

local function unanchor(character: Model)
	local root = rootOf(character)
	if not root or not root.Parent then return end

	if character:GetAttribute(Config.LooseAttribute) then
		character:SetAttribute(Config.LooseAttribute, nil)

		for _, limb in limbsOf(character) do
			limb.Anchored = false
		end
	end

	root.Anchored = false

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local parts = { root }

	for _, limb in limbsOf(character) do
		table.insert(parts, limb)
	end

	for _, part in parts do
		if part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(player)
		end
	end
end

local function isCarried(character: Instance?): boolean
	return character ~= nil and character:GetAttribute(Config.CarryAttribute) ~= nil
end

local function carryFrame(character: Model, elapsed: number, origin: CFrame?, duration: number?): CFrame?
	local velocity = character:GetAttribute(Config.CarryAttribute)
	local from = origin or character:GetAttribute(Config.CarryFromAttribute)
	local spin = character:GetAttribute(Config.CarrySpinAttribute)
	local flight = duration or character:GetAttribute(Config.CarryTimeAttribute)

	if typeof(velocity) ~= "Vector3" or typeof(from) ~= "CFrame" or typeof(flight) ~= "number" then return nil end

	local t = math.clamp(elapsed, 0, flight)
	local position = from.Position + velocity * t + Vector3.new(0, -0.5 * workspace.Gravity * t * t, 0)
	local rotation = from.Rotation

	if typeof(spin) == "Vector3" and spin.Magnitude > 1e-4 then
		rotation = CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * t) * rotation
	end

	return rotation + position
end

local function carryEntry(character: Model, root: BasePart)
	local from = character:GetAttribute(Config.CarryFromAttribute)
	local entry = carried[character]

	if entry and entry.From == from then return entry end

	local velocity = character:GetAttribute(Config.CarryAttribute)
	local origin = heldFrames[character] or root.CFrame
	local _, landing = TrajectoryService.Arc(origin.Position, velocity, root.Size)

	entry = {
		From = from,
		Origin = origin,
		Velocity = velocity,
		Duration = if landing then landing.Time else character:GetAttribute(Config.CarryTimeAttribute),
		SeenAt = os.clock(),
	}
	carried[character] = entry

	return entry
end

local function clearCarry(character: Model)
	character:SetAttribute(Config.CarryAttribute, nil)
	character:SetAttribute(Config.CarryFromAttribute, nil)
	character:SetAttribute(Config.CarrySpinAttribute, nil)
	character:SetAttribute(Config.CarryTimeAttribute, nil)
end

local function land(character: Model)
	carries[character] = nil

	local root = rootOf(character)
	local frame = carryFrame(character, math.huge)

	clearCarry(character)

	if root and frame and not Players:GetPlayerFromCharacter(character) then
		root.CFrame = frame
	end

	unanchor(character)
end

function PairSceneService.Carry(character: Model, velocity: Vector3, landing, motion): boolean
	assert(IS_SERVER, "PairSceneService.Carry runs on the server")

	local root = rootOf(character)
	if not root or not root.Anchored or not character:GetAttribute(Config.LooseAttribute) then return false end

	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local spin = Vector3.zero

	if typeof(motion) == "table" and typeof(motion.spin) == "number" and horizontal.Magnitude > 1e-3 then
		spin = Vector3.new(0, 1, 0):Cross(horizontal.Unit) * math.rad(motion.spin)
	end

	local duration = if typeof(landing) == "table" and typeof(landing.Time) == "number" then landing.Time else Config.CarryTimeout

	character:SetAttribute(Config.CarryFromAttribute, root.CFrame)
	character:SetAttribute(Config.CarrySpinAttribute, spin)
	character:SetAttribute(Config.CarryTimeAttribute, duration)
	character:SetAttribute(Config.CarryAttribute, velocity)

	if carries[character] then
		task.cancel(carries[character])
	end

	carries[character] = task.delay(duration + Config.CarryGrace, land, character)

	return true
end

PairSceneService.IsCarried = isCarried

local function roleOf(scene, character: Model): string
	return if character == scene.Attacker then "Attacker" else "Victim"
end

local function configuredRagdoll(scene, character: Model): number?
	local outcome = scene.Outcome and scene.Definition.Outcomes[scene.Outcome]
	local ragdolls = outcome and outcome.Ragdoll or scene.Definition.ReleaseRagdoll

	return ragdolls and ragdolls[roleOf(scene, character)]
end

local function launches(scene, character: Model): boolean
	local outcome = scene.Outcome and scene.Definition.Outcomes[scene.Outcome]
	local launch = outcome and outcome.Launch

	return launch ~= nil and launch[roleOf(scene, character)] == true
end

local function partnerIn(scene, character: Model): Model
	return if character == scene.Attacker then scene.Victim else scene.Attacker
end

local function ragdoll(character: Model, duration: number)
	if duration <= 0 or not isAlive(character) then return end

	require("./RagdollService").Ragdoll(character, duration)
	StatusService:ApplyStatus(character, "IsStunned", true, duration)
end

local function launch(scene, character: Model)
	PairSceneService.Launched:Fire(scene, character, partnerIn(scene, character))

	if not isCarried(character) then
		unanchor(character)
	end
end

local function freeMember(scene, character: Model)
	if not active[scene] or scene.Freed[character] then return end

	if launches(scene, character) then
		PairSceneService:Free(scene, character, true)
		launch(scene, character)
		return
	end

	scene.Freed[character] = true
	character:SetAttribute(Config.AnchorAttribute, nil)
	place(character, partnerIn(scene, character))
	unanchor(character)
	clearFollow(character)

	ragdoll(character, configuredRagdoll(scene, character) or scene.Definition.MarkerRagdoll or Config.MarkerRagdoll)
end

local function strike(scene, owner: Model, track: AnimationTrack)
	if not active[scene] then return end

	local hit = scene.Definition.Hit or Config.Hit
	local name = track.Animation and track.Animation.Name
	local targets = scene.Definition.HitTargets
	local target = if targets and targets[name] == "Self" then owner else partnerIn(scene, owner)

	if scene.Left[target] then return end

	PairSceneService.Struck:Fire(scene, partnerIn(scene, target), target, hit)
end

local function adopt(scene, character: Model, track: AnimationTrack)
	scene.Tracks[character] = scene.Tracks[character] or {}
	table.insert(scene.Tracks[character], track)

	table.insert(scene.Connections, track:GetMarkerReachedSignal(Config.RagdollMarker):Connect(function()
		freeMember(scene, character)
	end))

	table.insert(scene.Connections, track:GetMarkerReachedSignal((scene.Definition.Hit or Config.Hit).Marker):Connect(function()
		strike(scene, character, track)
	end))
end

local function settleMember(scene, character: Model): boolean
	local anchor = anchorOf(character)
	if not anchor then return false end

	local root = rootOf(character)
	local settled = root and Placement.Settled(character, anchor)

	if not settled then return false end

	for _, track in scene.Tracks[character] or {} do
		track:Stop(Config.SettleFade)
	end

	character:SetAttribute(Config.AnchorAttribute, settled)
	root.CFrame = settled

	return true
end

local function animationId(animation: Animation?): string?
	return animation and string.match(animation.AnimationId, "(%d+)%D*$")
end

local function sceneIds(definition): string
	local ids = {}

	local function add(name: string?)
		local id = name and animationId(AnimatorService:GetAnimation(name))

		if id and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end

	for _, side in { definition.Attacker, definition.Victim } do
		add(side.Intro)
		add(side.Loop)
	end

	for _, outcome in definition.Outcomes or {} do
		add(outcome.Attacker)
		add(outcome.Victim)
	end

	return table.concat(ids, ",")
end

local function isSceneTrack(character: Model, track: AnimationTrack): boolean
	if sceneTracks[track] then return true end

	local ids = character:GetAttribute(Config.TracksAttribute)
	local id = animationId(track.Animation)

	return id ~= nil and typeof(ids) == "string" and table.find(string.split(ids, ","), id) ~= nil
end

local function isHeld(character: Model): boolean
	return character.Parent ~= nil and (anchorOf(character) ~= nil or predictions[character] ~= nil)
end

local function guard(character: Model)
	if not isHeld(character) then return end

	local animator = AnimatorService:GetAnimator(character)
	if not animator then return end

	local muted = guards[character] or setmetatable({}, { __mode = "k" })
	guards[character] = muted

	for _, track in animator:GetPlayingAnimationTracks() do
		if track.WeightTarget <= Config.MutedWeight or not table.find(Config.MutePriorities, track.Priority) then continue end
		if isSceneTrack(character, track) then continue end

		muted[track] = track.WeightTarget
		track:AdjustWeight(Config.MutedWeight, Config.MuteFade)
	end
end

local function releaseGuards()
	for character, muted in guards do
		if isHeld(character) then continue end

		guards[character] = nil

		for track, weight in muted do
			if not track.IsPlaying then continue end

			if track.Looped then
				track:AdjustWeight(weight, Config.RestoreFade)
			else
				track:Stop(Config.RestoreFade)
			end
		end
	end
end

function PairSceneService.PlayTrack(character: Model, name: string, looped: boolean, fade: number, position: number?, shadow: boolean?): AnimationTrack?
	if not AnimatorService:HasAnimation(name) then return nil end

	if shadow then
		local animation = AnimatorService:GetAnimation(name)
		return animation and Timeline.Play(animation, looped, position)
	end

	local loaded, track = pcall(AnimatorService.GetTrack, AnimatorService, character, name)
	if not loaded or not track then return nil end

	sceneTracks[track] = true

	track.Priority = Config.TrackPriority
	track.Looped = looped
	track:Play(fade, 1)

	if position and position > 0 then
		track.TimePosition = position
	end

	return track
end

function PairSceneService.Sequence(character: Model, side, definition, age: number?, onTrack: ((AnimationTrack) -> ())?, shadow: boolean?)
	local sequence = { Tracks = {}, Stopped = false, Thread = nil }
	local skip = age or 0

	local function play(name: string?, looped: boolean, fade: number, position: number?): AnimationTrack?
		local track = name and PairSceneService.PlayTrack(character, name, looped, fade, position, shadow)

		if track then
			table.insert(sequence.Tracks, track)

			if onTrack then
				onTrack(track)
			end
		end

		return track
	end

	local intro = play(side.Intro, false, definition.IntroFade, skip)

	sequence.Thread = task.spawn(function()
		local began = os.clock()

		while intro and intro.Length <= 0 and os.clock() - began < 1 do
			task.wait()
		end

		local length = intro and intro.Length or 0

		task.wait(math.max(length - skip - definition.LoopFade - (os.clock() - began), 0))

		sequence.Thread = nil
		if sequence.Stopped then return end

		play(side.Loop, true, definition.LoopFade)

		if intro then
			intro:Stop(definition.LoopFade)
		end
	end)

	function sequence.Stop(fade: number)
		if sequence.Stopped then return end

		sequence.Stopped = true

		if sequence.Thread and coroutine.status(sequence.Thread) == "suspended" then
			task.cancel(sequence.Thread)
		end

		for _, track in sequence.Tracks do
			track:Stop(fade)
		end
	end

	return sequence
end

function PairSceneService.IsInScene(character: Model): boolean
	return character:GetAttribute(Config.SceneAttribute) ~= nil or predictions[character] ~= nil
end

function PairSceneService.PartnerOf(character: Model): (Model?, string?)
	local predicted = predictions[character]

	if predicted and predicted.Partner.Parent then
		return predicted.Partner, predicted.Definition.Name
	end

	local id = character:GetAttribute(Config.SceneAttribute)
	local live = liveFolder()

	if typeof(id) ~= "string" or not live then return nil, nil end

	for _, other in live:GetChildren() do
		if other ~= character and other:GetAttribute(Config.SceneAttribute) == id then
			return other, string.match(id, "^(.-)#")
		end
	end

	return nil, nil
end

function PairSceneService.SceneOf(character: Model)
	return members[character]
end

local function releaseReason(scene): string?
	for _, character in { scene.Attacker, scene.Victim } do
		if scene.Left[character] then continue end
		if not isAlive(character) or not rootOf(character) then return `{character.Name} died or left` end
		if scene.Freed[character] then continue end

		for _, status in scene.Definition.BreakOn or Config.BreakOn do
			if character:GetAttribute(status) == true then return `{character.Name} is {status}` end
		end
	end

	return nil
end

local function step()
	for scene in active do
		local reason = releaseReason(scene)

		if reason then
			PairSceneService:Release(scene, reason)
			continue
		end

		local ending = scene.EndTrack

		if ending and not scene.Outcome and ending.Length > 0 and (not ending.IsPlaying or ending.TimePosition >= ending.Length - Config.HoldLastFrame) then
			scene.EndTrack = nil
			scene.EndsAt = os.clock()
		end

		if scene.EndsAt and os.clock() >= scene.EndsAt then
			local timeout = scene.Definition.TimeoutOutcome

			if timeout and scene.Definition.Outcomes and scene.Definition.Outcomes[timeout] then
				PairSceneService:Resolve(scene, timeout)
			else
				PairSceneService:Release(scene, "held for the full duration")
				continue
			end
		end

		for _, character in { scene.Attacker, scene.Victim } do
			local root, anchor = rootOf(character), anchorOf(character)

			if root and anchor and not scene.Freed[character] then
				hold(root, anchor)
			end
		end
	end

	for character in members do
		guard(character)
	end

	releaseGuards()
end

function PairSceneService.Supports(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6 and character:FindFirstChild("Torso") ~= nil
end

function PairSceneService:Begin(definition, attacker: Model, victim: Model, options)
	assert(IS_SERVER, "PairSceneService:Begin runs on the server")

	options = options or {}

	if not PairSceneService.Supports(victim) then
		return nil, "victim's rig can't play paired scenes"
	end

	if definition.AttackerRig ~= "Any" and not PairSceneService.Supports(attacker) then
		return nil, "attacker's rig can't play paired scenes"
	end

	if members[attacker] or members[victim] then return nil, "already in a scene" end
	if isCarried(attacker) or isCarried(victim) then return nil, "in flight" end

	local RagdollService = require("./RagdollService")
	local downed = RagdollService.IsRagdolled(victim)

	if downed and definition.Victim.Ragdolled then
		local side = table.clone(definition.Victim)

		for key, value in definition.Victim.Ragdolled do
			side[key] = value
		end

		definition = table.clone(definition)
		definition.Victim = side
	end

	local victimPlaced, attackerPlaced = Placement.Place(definition, attacker, victim)
	if not victimPlaced or not attackerPlaced then return nil, "no clear ground for the scene" end

	nextId += 1

	local scene = {
		Id = `{definition.Name}#{nextId}`,
		Definition = definition,
		Attacker = attacker,
		Victim = victim,
		StartedAt = os.clock(),
		EndsAt = if typeof(definition.Duration) == "number" then os.clock() + definition.Duration else nil,
		OnRelease = options.OnRelease,
		Predicted = options.Predicted == true,
		Sequences = {},
		OutcomeTracks = {},
		Tracks = {},
		Freed = {},
		Left = {},
		Connections = {},
		Outcome = nil,
	}

	local ids = sceneIds(definition)

	for _, member in { { attacker, attackerPlaced, definition.Attacker }, { victim, victimPlaced, definition.Victim } } do
		local character, placed, side = member[1], member[2], member[3]

		character:SetAttribute(Config.SceneAttribute, scene.Id)
		character:SetAttribute(Config.TracksAttribute, ids)

		if side.Anchor ~= false then
			character:SetAttribute(Config.AnchorAttribute, placed)
			hold(rootOf(character), placed)
		end

		if not side.Ragdoll and RagdollService.IsRagdolled(character) then
			StatusService:RemoveStatus(character, RagdollService.Settings.Status)
		end

		StatusService:SetStatus(character, Config.Status, true)

		if side.Status then
			StatusService:SetStatus(character, side.Status, true)
		end

		members[character] = scene
	end

	local age = options.Age or 0

	table.insert(scene.Sequences, PairSceneService.Sequence(victim, definition.Victim, definition, age, function(track)
		adopt(scene, victim, track)
	end))

	local attackerSequence = PairSceneService.Sequence(attacker, definition.Attacker, definition, age, function(track)
		adopt(scene, attacker, track)
	end, scene.Predicted)

	table.insert(scene.Sequences, attackerSequence)

	if definition.Duration == "Attacker" then
		scene.EndTrack = attackerSequence.Tracks[1]
	end

	guard(attacker)
	guard(victim)

	for _, member in { { attacker, definition.Attacker }, { victim, definition.Victim } } do
		local character, side = member[1], member[2]
		local follow = side.Follow

		if follow then
			startFollow(character, if character == attacker then victim else attacker, follow)
		end

		if side.Ragdoll then
			ragdoll(character, side.Ragdoll)

			if side.Anchor ~= false then
				loosen(character)
			end
		end
	end

	active[scene] = true

	if not stepper then
		stepper = RunService.Heartbeat:Connect(step)
	end

	PairSceneService.Started:Fire(scene)

	return scene
end

function PairSceneService:Release(scene, reason: string?)
	if not active[scene] then return end

	if DebugService.IsEnabled() then
		warn(`[PairScene] {scene.Id} ended ({scene.Attacker.Name} -> {scene.Victim.Name}): {reason or "released"}`)
	end

	if scene.OutcomeThread and coroutine.running() ~= scene.OutcomeThread then
		task.cancel(scene.OutcomeThread)
		scene.OutcomeThread = nil
	end

	for _, connection in scene.Connections do
		connection:Disconnect()
	end

	for _, character in { scene.Attacker, scene.Victim } do
		if not scene.Freed[character] and character.Parent then
			settleMember(scene, character)
		end
	end

	active[scene] = nil

	local fade = scene.Definition.ReleaseFade

	for _, sequence in scene.Sequences do
		sequence.Stop(fade)
	end

	for _, track in scene.OutcomeTracks do
		track:Stop(fade)
	end

	for _, member in { { scene.Attacker, scene.Definition.Attacker }, { scene.Victim, scene.Definition.Victim } } do
		local character, side = member[1], member[2]
		local freed = scene.Freed[character]

		if scene.Left[character] then continue end

		if members[character] == scene then
			members[character] = nil
		end

		character:SetAttribute(Config.SceneAttribute, nil)
		character:SetAttribute(Config.TracksAttribute, nil)
		character:SetAttribute(Config.AnchorAttribute, nil)

		local launching = not freed and character.Parent ~= nil and launches(scene, character)

		if not freed then
			place(character, partnerIn(scene, character))

			if not launching then
				unanchor(character)
			end
		end

		clearFollow(character)
		character:SetAttribute(Config.OutcomeAttribute, nil)

		if character.Parent then
			StatusService:RemoveStatus(character, Config.Status)

			if side.Status then
				StatusService:RemoveStatus(character, side.Status)
			end

			local fallback = configuredRagdoll(scene, character)

			if launching then
				launch(scene, character)
			elseif not freed and fallback then
				ragdoll(character, fallback)
			end
		end
	end

	if scene.OnRelease then
		task.spawn(scene.OnRelease, reason, scene.Outcome)
	end
end

function PairSceneService:Free(scene, character: Model, held: boolean?): boolean
	assert(IS_SERVER, "PairSceneService:Free runs on the server")

	if not active[scene] or scene.Left[character] then return false end
	if character ~= scene.Attacker and character ~= scene.Victim then return false end

	local side = scene.Definition[roleOf(scene, character)]

	scene.Left[character] = true
	scene.Freed[character] = true

	for _, track in scene.Tracks[character] or {} do
		track:Stop(scene.Definition.ReleaseFade)
	end

	if members[character] == scene then
		members[character] = nil
	end

	character:SetAttribute(Config.SceneAttribute, nil)
	character:SetAttribute(Config.TracksAttribute, nil)
	character:SetAttribute(Config.AnchorAttribute, nil)
	place(character, partnerIn(scene, character))

	if not held then
		unanchor(character)
	end

	clearFollow(character)
	character:SetAttribute(Config.OutcomeAttribute, nil)

	if character.Parent then
		StatusService:RemoveStatus(character, Config.Status)

		if side.Status then
			StatusService:RemoveStatus(character, side.Status)
		end
	end

	return true
end

function PairSceneService:Resolve(scene, outcomeName: string): boolean
	assert(IS_SERVER, "PairSceneService:Resolve runs on the server")

	if not active[scene] or scene.Outcome then return false end

	local definition = scene.Definition
	local outcome = definition.Outcomes and definition.Outcomes[outcomeName]

	if not outcome then
		self:Release(scene, `{outcomeName} has no outcome animations`)
		return false
	end

	scene.Outcome = outcomeName
	scene.EndsAt = nil

	for _, sequence in scene.Sequences do
		sequence.Stop(definition.LoopFade)
	end

	for _, member in { { scene.Attacker, outcome.Attacker }, { scene.Victim, outcome.Victim } } do
		local character, name = member[1], member[2]

		character:SetAttribute(Config.OutcomeAttribute, outcomeName)

		local track = name and PairSceneService.PlayTrack(character, name, false, definition.LoopFade)

		if track then
			table.insert(scene.OutcomeTracks, track)
			adopt(scene, character, track)
		end
	end

	PairSceneService.Resolved:Fire(scene, outcomeName)

	for role, delay in outcome.ReleaseAt or {} do
		local character = if role == "Attacker" then scene.Attacker else scene.Victim

		task.delay(delay, function()
			if active[scene] and scene.Outcome == outcomeName and not scene.Freed[character] then
				freeMember(scene, character)
			end
		end)
	end

	scene.OutcomeThread = task.spawn(function()
		local began = os.clock()

		while true do
			local finished = true

			for _, track in scene.OutcomeTracks do
				if not track.IsPlaying then continue end

				if track.Length <= 0 then
					finished = finished and os.clock() - began > 1
				elseif track.TimePosition >= track.Length - Config.HoldLastFrame then
					if track.Speed ~= 0 then
						track:AdjustSpeed(0)
					end
				else
					finished = false
				end
			end

			if finished then break end

			RunService.Heartbeat:Wait()
		end

		scene.OutcomeThread = nil
		self:Release(scene, `outcome {outcomeName}`)
	end)

	return true
end

function PairSceneService.HoldAnchors()
	local live = liveFolder()

	if live then
		for _, character in live:GetChildren() do
			local anchor = anchorOf(character)
			local root = (anchor or isCarried(character)) and rootOf(character)
			local entry = root and not anchor and carryEntry(character, root)
			local flight = entry and carryFrame(character, os.clock() - entry.SeenAt, entry.Origin, entry.Duration)

			if root and (anchor or flight) then
				local frame = flight or followFrame(character, (PairSceneService.PartnerOf(character))) or anchor

				heldRoots[root] = true
				heldFrames[character] = frame
				hold(root, frame)

				if character:GetAttribute(Config.LooseAttribute) then
					loosenLocally(character)
				end
			end
		end
	end

	local own = Players.LocalPlayer and Players.LocalPlayer.Character

	for root in heldRoots do
		local character = root.Parent
		if anchorOf(character) or isCarried(character) or (character and predictions[character]) then continue end

		heldRoots[root] = nil

		if not character then continue end

		root.Anchored = false

		local thrown = carried[character]
		carried[character] = nil

		if thrown and character == own then
			local t = os.clock() - thrown.SeenAt

			root.AssemblyLinearVelocity = if t < thrown.Duration
				then thrown.Velocity + Vector3.new(0, -workspace.Gravity * t, 0)
				else Vector3.new(thrown.Velocity.X, 0, thrown.Velocity.Z) * Config.LandingCarry
		end
	end

	if own then
		guard(own)
	end

	releaseGuards()
end

function PairSceneService.Predict(character: Model, definition, partner: Model)
	local root = rootOf(character)
	if not root then return nil end

	local _, placed = Placement.Place(definition, character, partner)
	if not placed then return nil end

	hold(root, placed)
	heldRoots[root] = true
	predictions[character] = { Partner = partner, Definition = definition }

	local sequence = PairSceneService.Sequence(character, definition.Attacker, definition)
	guard(character)

	local handle = { StartedAt = os.clock(), Confirmed = false, Stopped = false, Resolved = false, Rejected = nil }

	function handle:State(): string
		if self.Stopped or self.Rejected then return "ended" end

		local inScene = character:GetAttribute(Config.SceneAttribute) ~= nil

		if not self.Resolved and character:GetAttribute(Config.OutcomeAttribute) ~= nil then
			self.Resolved = true
			sequence.Stop(definition.LoopFade)
		end

		if not self.Confirmed then
			if inScene then
				self.Confirmed = true
				return "active"
			end

			return if os.clock() - self.StartedAt > definition.ConfirmWindow then "ended" else "pending"
		end

		return if inScene then "active" else "ended"
	end

	function handle:Reject(reason: string?)
		if self.Confirmed then return end
		self.Rejected = reason or "rejected"
	end

	function handle:Stop(fade: number)
		if self.Stopped then return end

		self.Stopped = true

		local settled = self.Confirmed and not self.Resolved and Placement.Settled(character, root.CFrame) or nil

		sequence.Stop(if settled then Config.SettleFade else fade)

		if predictions[character] and predictions[character].Partner == partner then
			predictions[character] = nil
		end

		if root.Parent and not anchorOf(character) then
			root.Anchored = false
			heldRoots[root] = nil

			if settled then
				root.CFrame = settled
			end
		end
	end

	return handle
end

return PairSceneService
