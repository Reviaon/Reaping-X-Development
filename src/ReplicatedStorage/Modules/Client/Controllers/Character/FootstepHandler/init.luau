--[[@
	**FootstepHandler**: footprint puffs under every planted foot, and pebbles kicked up when sprinting
	- **Who:** every player body with R6 legs (`Config.Legs`) within `Config.Range` of the camera; drawn on each client, nothing is networked
	- **When** (`Stride`): a foot plants at heel strike, when its tip stops reaching ahead along the way the body moves
	  - Works for any clip at any speed, walking backwards or strafing too; one swing is one step
	  - Only while moving faster than `MinSpeed` on the ground
	- **Ground** (`Ground`): the floor under the foot picks the kind (grass, sand, or ground for anything else) and gives its colour
	- **Prints** (`Prints`): the kind's part under `MovementVFX.Footstep` is recoloured to the floor's colour and emitted through ForgeVFX
	  - Authored in grey: each emitter keeps its shade relative to the brightest in its part
	  - Pooled copies are used in turn, so recolouring one never repaints prints still fading
	- **Sounds** (`Sounds`): each plant plays the kind's `Footsteps` sound from the leg, `Run` at `Config.Sounds.RunSpeed` and over, `Walk` under it
	- **Pebbles** (`Pebbles`): at sprint speed each plant flicks a few tiny blocks of the floor's material and colour back behind the runner
	- **A new ground** is a new part under `Footstep` and lines in `Config.Kinds` / `Config.Materials`
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local FootstepHandler = Jloader.CreateHandler({ Name = script.Name })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@self/Config")
local Ground = require("@self/Ground")
local Pebbles = require("@self/Pebbles")
local Prints = require("@self/Prints")
local Sounds = require("@self/Sounds")
local Stride = require("@self/Stride")
local Types = require("@self/Types")

local FLAT = Vector3.new(1, 0, 1)
local RESCAN = 0.5

local watched: { [Model]: Types.Watch } = {}
local rescanAt = 0
local started = false

local function find(root: Instance, path: { string }): Instance?
	local found: Instance? = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function watchOf(character: Model): Types.Watch?
	local existing = watched[character]
	if existing then return existing end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then return nil end

	local feet: { Types.Foot } = {}

	for _, name in Config.Legs do
		local leg = character:FindFirstChild(name)
		if not leg or not leg:IsA("BasePart") then return nil end

		table.insert(feet, Stride.Foot(leg))
	end

	local watch: Types.Watch = { Character = character, Root = root, Humanoid = humanoid, Feet = feet }
	watched[character] = watch

	return watch
end

local function rescan()
	local camera = workspace.CurrentCamera
	local origin = if camera then camera.CFrame.Position else Vector3.zero
	local ignore: { Instance } = {}
	local keep: { [Model]: boolean } = {}

	for _, path in { Config.Visuals, { "World", "Live" } } do
		local folder = find(workspace, path)

		if folder then
			table.insert(ignore, folder)
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not character or not root or not root:IsA("BasePart") then continue end

		table.insert(ignore, character)

		if (root.Position - origin).Magnitude <= Config.Range and watchOf(character) then
			keep[character] = true
			Sounds.MuteDefaults(root)
		end
	end

	for character in watched do
		if not keep[character] then
			watched[character] = nil
		end
	end

	Ground.Ignore(ignore)
end

local function step(watch: Types.Watch)
	local root = watch.Root
	local velocity = root.AssemblyLinearVelocity * FLAT
	local speed = velocity.Magnitude

	if not root.Parent or watch.Humanoid.Health <= 0 or speed < Config.MinSpeed or watch.Humanoid.FloorMaterial == Enum.Material.Air then
		for _, foot in watch.Feet do
			Stride.Reset(foot)
		end

		return
	end

	local heading = velocity.Unit

	for _, foot in watch.Feet do
		if not Stride.Planted(foot, heading) then continue end

		local ground = Ground.Under(Stride.Tip(foot.Leg))
		if not ground then continue end

		Prints.Step(ground, heading)
		Sounds.Step(foot.Leg, ground, speed)

		if speed >= Config.Pebbles.Speed then
			Pebbles.Kick(ground, heading)
		end
	end
end

function FootstepHandler:Load()
	if started then return end
	started = true

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()

		if now >= rescanAt then
			rescanAt = now + RESCAN
			rescan()
		end

		for _, watch in watched do
			step(watch)
		end

		Pebbles.Step(dt)
	end)
end

return FootstepHandler
