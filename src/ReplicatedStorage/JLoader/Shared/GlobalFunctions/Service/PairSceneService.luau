local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatusService = require("./StatusService")
local AnimatorService = require("./AnimatorService")
local DebugService = require("./DebugService")

local PairSceneService = {
	Settings = {
		SceneAttribute = "PairScene",
		AnchorAttribute = "PairSceneAnchor",
		Status = "InPairScene",
		TrackPriority = Enum.AnimationPriority.Action4,
		BreakOn = { "IsRagdolled" },
		LivePath = { "World", "Live" },
	},
}

local Settings = PairSceneService.Settings
local IS_SERVER = RunService:IsServer()

local active = {}
local members = {}
local predictions = {}
local heldRoots = {}
local nextId = 0
local stepper = nil

local function rootOf(character: Instance?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function liveFolder(): Instance?
	local found = workspace

	for _, segment in Settings.LivePath do
		found = found:FindFirstChild(segment)
		if not found then return nil end
	end

	return found
end

local function anchorOf(character: Instance?): CFrame?
	local anchor = character and character:GetAttribute(Settings.AnchorAttribute)
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

function PairSceneService.Align(definition, victim: CFrame, from: Vector3): (CFrame, CFrame)
	local position = victim.Position
	local toward = (from - position) * Vector3.new(1, 0, 1)

	if toward.Magnitude <= 1e-3 then
		toward = victim.LookVector * Vector3.new(1, 0, 1)
	end

	local facing = CFrame.lookAt(position, position + toward.Unit)

	return facing, facing * CFrame.new(0, 0, -definition.Spacing) * CFrame.Angles(0, math.pi, 0)
end

function PairSceneService.PlayTrack(character: Model, name: string, looped: boolean, fade: number, position: number?): AnimationTrack?
	if not AnimatorService:HasAnimation(name) then return nil end

	local loaded, track = pcall(AnimatorService.GetTrack, AnimatorService, character, name)
	if not loaded or not track then return nil end

	track.Priority = Settings.TrackPriority
	track.Looped = looped
	track:Play(fade)

	if position and position > 0 then
		track.TimePosition = position
	end

	return track
end

function PairSceneService.Sequence(character: Model, side, definition, age: number?)
	local sequence = { Tracks = {}, Stopped = false, Thread = nil }
	local skip = age or 0
	local intro = side.Intro and PairSceneService.PlayTrack(character, side.Intro, false, definition.IntroFade, skip)

	if intro then
		table.insert(sequence.Tracks, intro)
	end

	sequence.Thread = task.spawn(function()
		local began = os.clock()

		while intro and intro.Length <= 0 and os.clock() - began < 1 do
			task.wait()
		end

		local length = intro and intro.Length or 0

		task.wait(math.max(length - skip - definition.LoopFade - (os.clock() - began), 0))

		sequence.Thread = nil
		if sequence.Stopped then return end

		local loop = side.Loop and PairSceneService.PlayTrack(character, side.Loop, true, definition.LoopFade)

		if loop then
			table.insert(sequence.Tracks, loop)
		end

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
	return character:GetAttribute(Settings.SceneAttribute) ~= nil or predictions[character] ~= nil
end

function PairSceneService.PartnerOf(character: Model): (Model?, string?)
	local predicted = predictions[character]

	if predicted and predicted.Partner.Parent then
		return predicted.Partner, predicted.Definition.Name
	end

	local id = character:GetAttribute(Settings.SceneAttribute)
	local live = liveFolder()

	if typeof(id) ~= "string" or not live then return nil, nil end

	for _, other in live:GetChildren() do
		if other ~= character and other:GetAttribute(Settings.SceneAttribute) == id then
			return other, string.match(id, "^(.-)#")
		end
	end

	return nil, nil
end

function PairSceneService.SceneOf(character: Model)
	return members[character]
end

local function releaseReason(scene): string?
	if scene.EndsAt and os.clock() >= scene.EndsAt then return "held for the full duration" end

	for _, character in { scene.Attacker, scene.Victim } do
		if not isAlive(character) or not rootOf(character) then return `{character.Name} died or left` end

		for _, status in scene.Definition.BreakOn or Settings.BreakOn do
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

		for _, character in { scene.Attacker, scene.Victim } do
			local root, anchor = rootOf(character), anchorOf(character)

			if root and anchor then
				hold(root, anchor)
			end
		end
	end
end

function PairSceneService:Begin(definition, attacker: Model, victim: Model, options)
	assert(IS_SERVER, "PairSceneService:Begin runs on the server")

	options = options or {}

	if members[attacker] or members[victim] then return nil end

	local attackerRoot, victimRoot = rootOf(attacker), rootOf(victim)
	if not attackerRoot or not victimRoot then return nil end

	local victimPlaced, attackerPlaced = PairSceneService.Align(definition, victimRoot.CFrame, attackerRoot.Position)

	nextId += 1

	local scene = {
		Id = `{definition.Name}#{nextId}`,
		Definition = definition,
		Attacker = attacker,
		Victim = victim,
		StartedAt = os.clock(),
		EndsAt = definition.Duration and os.clock() + definition.Duration or nil,
		OnRelease = options.OnRelease,
		Sequences = {},
	}

	for _, member in { { attacker, attackerPlaced, definition.Attacker }, { victim, victimPlaced, definition.Victim } } do
		local character, placed, side = member[1], member[2], member[3]

		character:SetAttribute(Settings.SceneAttribute, scene.Id)
		character:SetAttribute(Settings.AnchorAttribute, placed)
		hold(rootOf(character), placed)

		StatusService:SetStatus(character, Settings.Status, true)

		if side.Status then
			StatusService:SetStatus(character, side.Status, true)
		end

		members[character] = scene
	end

	local age = options.Age or 0

	table.insert(scene.Sequences, PairSceneService.Sequence(victim, definition.Victim, definition, age))

	if not options.Predicted then
		table.insert(scene.Sequences, PairSceneService.Sequence(attacker, definition.Attacker, definition, age))
	end

	active[scene] = true

	if not stepper then
		stepper = RunService.Heartbeat:Connect(step)
	end

	return scene
end

function PairSceneService:Release(scene, reason: string?)
	if not active[scene] then return end

	active[scene] = nil

	if DebugService.IsEnabled() then
		warn(`[PairScene] {scene.Id} ended ({scene.Attacker.Name} -> {scene.Victim.Name}): {reason or "released"}`)
	end

	for _, sequence in scene.Sequences do
		sequence.Stop(scene.Definition.ReleaseFade)
	end

	for _, member in { { scene.Attacker, scene.Definition.Attacker }, { scene.Victim, scene.Definition.Victim } } do
		local character, side = member[1], member[2]

		if members[character] == scene then
			members[character] = nil
		end

		character:SetAttribute(Settings.SceneAttribute, nil)
		character:SetAttribute(Settings.AnchorAttribute, nil)

		local root = rootOf(character)

		if root and root.Parent then
			root.Anchored = false

			local player = Players:GetPlayerFromCharacter(character)

			if player and root:CanSetNetworkOwnership() then
				root:SetNetworkOwner(player)
			end
		end

		if character.Parent then
			StatusService:RemoveStatus(character, Settings.Status)

			if side.Status then
				StatusService:RemoveStatus(character, side.Status)
			end
		end
	end

	if scene.OnRelease then
		task.spawn(scene.OnRelease, reason)
	end
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
end

function PairSceneService.Predict(character: Model, definition, partner: Model)
	local root, partnerRoot = rootOf(character), rootOf(partner)
	if not root or not partnerRoot then return nil end

	local _, placed = PairSceneService.Align(definition, partnerRoot.CFrame, root.Position)

	hold(root, placed)
	heldRoots[root] = true
	predictions[character] = { Partner = partner, Definition = definition }

	local sequence = PairSceneService.Sequence(character, definition.Attacker, definition)
	local handle = { StartedAt = os.clock(), Confirmed = false, Stopped = false, Rejected = nil }

	function handle:State(): string
		if self.Stopped or self.Rejected then return "ended" end

		local inScene = character:GetAttribute(Settings.SceneAttribute) ~= nil

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
		sequence.Stop(fade)

		if predictions[character] and predictions[character].Partner == partner then
			predictions[character] = nil
		end

		if root.Parent and not anchorOf(character) then
			root.Anchored = false
			heldRoots[root] = nil
		end
	end

	return handle
end

return PairSceneService
