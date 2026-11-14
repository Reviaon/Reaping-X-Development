-- Standalone ragdoll for R6 rigs: the soft-limit / muscle ragdoll of the `Ragdoll` module (R15),
-- separate copy. Same API, attributes and stream; its own tag, constraint folder and remotes, so
-- both run side by side. autoPlayers only takes R6 characters.
--
--   Server:  Ragdoll.Start({ autoPlayers = true, ragdollOnDeath = true })
--            Ragdoll.Setup(model, "Soft")          -- R6 rigs only (Torso + RootJoint); false otherwise
--            Ragdoll.SetEnabled(model, true/false)
--            Ragdoll.SetProfile(model, "Hard" | "Soft")
--            Ragdoll.Fling(model, velocity, at?)  -- NPCs; ragdolls, hits the torso (at = hit point)
--   Client:  Ragdoll.Start()
--            Ragdoll.SetEnabled(Players.LocalPlayer.Character, bool)   -- needs AllowClientRequests
--            Ragdoll.Fling(Players.LocalPlayer.Character, velocity)    -- once RagdollEnabled is true
--
-- State lives in attributes so it can be driven from the Properties panel during a playtest:
--   on a rig:        RagdollEnabled, RagdollProfile, RagdollStrengthScale, RagdollDampingScale,
--                    RagdollSoftScale, RagdollUprightOnExit, RagdollGravityScale, RagdollDragScale
--   on this module:  Replication ("Stream" | "Native"), Debug, AllowClientRequests

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Profiles = require(script.Profiles)
local Rig = require(script.Rig)
local Simulator = require(script.Simulator)
local Stream = require(script.Stream)

local Ragdoll = {}
Ragdoll.Profiles = Profiles

local IS_SERVER = RunService:IsServer()
local TUNING_ATTRIBUTES = {
	"RagdollProfile",
	"RagdollStrengthScale",
	"RagdollDampingScale",
	"RagdollSoftScale",
	"RagdollGravityScale",
	"RagdollDragScale",
}

local started = false
local options = {}
local requestRemote: RemoteEvent?
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function getRemote(name: string, className: string): Instance
	if IS_SERVER then
		local folder = script:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = script
		end
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	end
	return script:WaitForChild("Remotes"):WaitForChild(name)
end

local function waitForRig(model: Model, timeout: number)
	local deadline = os.clock() + timeout
	while model.Parent and os.clock() < deadline do
		local rig = Rig.get(model)
		if rig then
			return rig
		end
		task.wait(0.1)
	end
	return nil
end

-- ---------------------------------------------------------------------------------------------
-- Server

local function holdPlayerPin(rig, player: Player)
	local model = rig.model
	task.spawn(function()
		while model.Parent and model:GetAttribute("RagdollEnabled") == true do
			Simulator.pin(rig, player)
			task.wait(Simulator.PIN_INTERVAL)
		end
	end)
end

local function serverWatch(rig)
	local model = rig.model
	if watched[model] then
		return
	end
	watched[model] = true
	local player = Players:GetPlayerFromCharacter(model)

	local mirrored = false
	local function onEnabled()
		local on = model:GetAttribute("RagdollEnabled") == true
		if player then
			-- Player rigs are simulated by their owner, but the server has to split its own copy
			-- too: network ownership is handed out per server-side assembly, and an assembly only
			-- the client split off has no owner at all, so nothing simulates it and it freezes.
			local mirror = on
			if mirror ~= mirrored then
				mirrored = mirror
				Simulator.setRigid(rig, not mirror)
				if mirror then
					holdPlayerPin(rig, player)
				end
			end
		else
			Simulator.set(rig, on)
		end
	end
	model:GetAttributeChangedSignal("RagdollEnabled"):Connect(onEnabled)

	for _, attribute in TUNING_ATTRIBUTES do
		model:GetAttributeChangedSignal(attribute):Connect(function()
			Rig.applyProfile(rig)
			Simulator.reloadProfile(model)
		end)
	end

	if options.ragdollOnDeath ~= false then
		rig.humanoid.Died:Connect(function()
			model:SetAttribute("RagdollEnabled", true)
		end)
	end
	onEnabled()
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	if not player:HasAppearanceLoaded() then
		local deadline = os.clock() + 5
		while not player:HasAppearanceLoaded() and os.clock() < deadline and character.Parent do
			task.wait(0.1)
		end
	end
	if character.Parent and player.Character == character and Rig.isR6(character) then
		Ragdoll.Setup(character, options.playerProfile)
	end
end

local function startServer()
	if script:GetAttribute("Replication") == nil then
		script:SetAttribute("Replication", options.replication or "Stream")
	end
	if script:GetAttribute("Debug") == nil then
		script:SetAttribute("Debug", false)
	end
	if script:GetAttribute("AllowClientRequests") == nil then
		script:SetAttribute("AllowClientRequests", options.allowClientRequests == true)
	end

	Stream.start(getRemote("Stream", "UnreliableRemoteEvent") :: UnreliableRemoteEvent)
	requestRemote = getRemote("Request", "RemoteEvent") :: RemoteEvent
	requestRemote.OnServerEvent:Connect(function(player, enabled)
		local character = player.Character
		if script:GetAttribute("AllowClientRequests") ~= true or not character or type(enabled) ~= "boolean" then
			return
		end
		if CollectionService:HasTag(character, Rig.TAG) then
			character:SetAttribute("RagdollEnabled", enabled)
		end
	end)

	if options.autoPlayers ~= false then
		local function onPlayer(player: Player)
			player.CharacterAdded:Connect(function(character)
				setupCharacter(player, character)
			end)
			if player.Character then
				task.spawn(setupCharacter, player, player.Character)
			end
		end
		Players.PlayerAdded:Connect(onPlayer)
		for _, player in Players:GetPlayers() do
			onPlayer(player)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Client

local function clientTrack(model: Model)
	task.spawn(function()
		local rig = waitForRig(model, 15)
		if not rig then
			return
		end
		if model == Players.LocalPlayer.Character then
			if watched[model] then
				return
			end
			watched[model] = true
			local function onEnabled()
				Simulator.set(rig, model:GetAttribute("RagdollEnabled") == true)
			end
			model:GetAttributeChangedSignal("RagdollEnabled"):Connect(onEnabled)
			for _, attribute in TUNING_ATTRIBUTES do
				model:GetAttributeChangedSignal(attribute):Connect(function()
					Simulator.reloadProfile(model)
				end)
			end
			onEnabled()
		else
			Stream.observe(rig)
		end
	end)
end

local function startClient()
	Stream.start(getRemote("Stream", "UnreliableRemoteEvent") :: UnreliableRemoteEvent)
	requestRemote = getRemote("Request", "RemoteEvent") :: RemoteEvent

	CollectionService:GetInstanceAddedSignal(Rig.TAG):Connect(clientTrack)
	CollectionService:GetInstanceRemovedSignal(Rig.TAG):Connect(function(model)
		Stream.forget(model)
		Rig.forget(model)
	end)
	for _, model in CollectionService:GetTagged(Rig.TAG) do
		clientTrack(model)
	end
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		if CollectionService:HasTag(character, Rig.TAG) then
			clientTrack(character)
		end
	end)
	script:GetAttributeChangedSignal("Debug"):Connect(function()
		Stream.setDebug(script:GetAttribute("Debug") == true)
	end)
end

-- ---------------------------------------------------------------------------------------------
-- API

function Ragdoll.Start(startOptions: { [string]: any }?)
	if started then
		return
	end
	started = true
	options = startOptions or {}
	Simulator.onSample = Stream.send
	Simulator.start()
	if IS_SERVER then
		startServer()
	else
		startClient()
	end
end

function Ragdoll.IsR6(model: Model): boolean
	return Rig.isR6(model)
end

function Ragdoll.Setup(model: Model, profile: string?)
	local rig = Rig.setup(model, profile)
	if rig then
		serverWatch(rig)
	end
	return rig ~= nil
end

function Ragdoll.SetEnabled(model: Model, enabled: boolean)
	if IS_SERVER then
		model:SetAttribute("RagdollEnabled", enabled)
	elseif model == Players.LocalPlayer.Character and requestRemote then
		requestRemote:FireServer(enabled)
	end
end

function Ragdoll.IsEnabled(model: Model): boolean
	return model:GetAttribute("RagdollEnabled") == true
end

function Ragdoll.Toggle(model: Model)
	Ragdoll.SetEnabled(model, not Ragdoll.IsEnabled(model))
end

-- Must run where the rig is simulated: the server for NPCs, the owner for its own character.
function Ragdoll.Fling(model: Model, velocity: Vector3, at: Vector3?, spin: Vector3?): boolean
	if IS_SERVER then
		model:SetAttribute("RagdollEnabled", true)
		-- The attribute's changed signal is deferred, so the simulator has no state for this rig yet
		-- and would drop the launch. Queue the ragdoll here; the signal later repeats it harmlessly.
		local rig = Rig.get(model)
		if rig and not Players:GetPlayerFromCharacter(model) then
			Simulator.set(rig, true)
		end
	end
	return Simulator.fling(model, velocity, at, spin)
end

function Ragdoll.SetProfile(model: Model, profile: string)
	assert(IS_SERVER, "SetProfile is server-only")
	assert(Profiles[profile] and type(Profiles[profile]) == "table", `unknown ragdoll profile {profile}`)
	model:SetAttribute("RagdollProfile", profile)
end

return Ragdoll
