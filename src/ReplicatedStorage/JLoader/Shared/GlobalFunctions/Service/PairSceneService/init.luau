local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatusService = require("./StatusService")
local AnimatorService = require("./AnimatorService")
local DebugService = require("./DebugService")
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
local sceneTracks = setmetatable({}, { __mode = "k" })
local guards = {}
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

local function unanchor(character: Model)
	local root = rootOf(character)
	if not root or not root.Parent then return end

	root.Anchored = false

	local player = Players:GetPlayerFromCharacter(character)

	if player and root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(player)
	end
end

local function roleOf(scene, character: Model): string
	return if character == scene.Attacker then "Attacker" else "Victim"
end

local function configuredRagdoll(scene, character: Model): number?
	local outcome = scene.Outcome and scene.Definition.Outcomes[scene.Outcome]
	local ragdolls = outcome and outcome.Ragdoll

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

local function freeMember(scene, character: Model)
	if not active[scene] or scene.Freed[character] then return end

	if launches(scene, character) then
		PairSceneService:Free(scene, character)
		PairSceneService.Launched:Fire(scene, character, partnerIn(scene, character))
		return
	end

	scene.Freed[character] = true
	character:SetAttribute(Config.AnchorAttribute, nil)
	unanchor(character)

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
	local root = rootOf(character)
	local settled = root and Placement.Settled(character, anchorOf(character))

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

	if not PairSceneService.Supports(attacker) or not PairSceneService.Supports(victim) then
		return nil, "rig can't play paired scenes"
	end

	if members[attacker] or members[victim] then return nil, "already in a scene" end

	local victimPlaced, attackerPlaced = Placement.Place(definition, attacker, victim)
	if not victimPlaced or not attackerPlaced then return nil, "no clear ground for the scene" end

	nextId += 1

	local scene = {
		Id = `{definition.Name}#{nextId}`,
		Definition = definition,
		Attacker = attacker,
		Victim = victim,
		StartedAt = os.clock(),
		EndsAt = definition.Duration and os.clock() + definition.Duration or nil,
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
		character:SetAttribute(Config.AnchorAttribute, placed)
		hold(rootOf(character), placed)

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

	table.insert(scene.Sequences, PairSceneService.Sequence(attacker, definition.Attacker, definition, age, function(track)
		adopt(scene, attacker, track)
	end, scene.Predicted))

	guard(attacker)
	guard(victim)

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
		character:SetAttribute(Config.OutcomeAttribute, nil)

		if not freed then
			unanchor(character)
		end

		if character.Parent then
			StatusService:RemoveStatus(character, Config.Status)

			if side.Status then
				StatusService:RemoveStatus(character, side.Status)
			end

			local fallback = configuredRagdoll(scene, character)

			if not freed and launches(scene, character) then
				PairSceneService.Launched:Fire(scene, character, partnerIn(scene, character))
			elseif not freed and fallback then
				ragdoll(character, fallback)
			end
		end
	end

	if scene.OnRelease then
		task.spawn(scene.OnRelease, reason, scene.Outcome)
	end
end

function PairSceneService:Free(scene, character: Model): boolean
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
	character:SetAttribute(Config.OutcomeAttribute, nil)
	unanchor(character)

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
			local root = anchor and rootOf(character)

			if root then
				heldRoots[root] = true
				hold(root, anchor)
			end
		end
	end

	for root in heldRoots do
		local character = root.Parent
		if anchorOf(character) or (character and predictions[character]) then continue end

		heldRoots[root] = nil

		if character then
			root.Anchored = false
		end
	end

	local own = Players.LocalPlayer and Players.LocalPlayer.Character

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
