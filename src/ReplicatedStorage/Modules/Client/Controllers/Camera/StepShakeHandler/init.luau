--[[@
	**StepShakeHandler**: nearby players feel a big mob's steps
	- **Opt-in by config:** a MobLibrary entry with a `footsteps` module (`MobTypes.Footsteps`) is watched; nothing else is
	- **Timing:** each frame it reads the mob's playing gait tracks (`gaits`, keyed like `animations`) and shakes when a clip's phase passes one of its `at` shares, so steps follow the playback speed
	- **Gaits:** each has its own shape; when two strike together, the one with the heavier blend weight wins
	- **Strength:** the shape is scaled by closeness, full at the mob and nothing at `range`; several mobs stepping on one frame give one shake, the strongest
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local StepShakeHandler = Jloader.CreateHandler({ Name = script.Name })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Config = require("@self/Config")

type Gait = {
	Settings: MobTypes.Gait,
	Ids: { [string]: boolean },
	Names: { [string]: boolean },
}

type Profile = {
	Settings: MobTypes.Footsteps,
	Gaits: { [string]: Gait },
}

type Stride = {
	Track: AnimationTrack,
	Last: number?,
}

type Watch = {
	Root: BasePart,
	Profile: Profile,
	Strides: { [string]: Stride },
}

local profiles: { [string]: Profile | false } = {}
local watched: { [Model]: Watch } = {}
local cameraHandler = nil
local rescanAt = 0

local function find(root: Instance, path: { string }): Instance?
	local found: Instance? = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function requireChild(entry: Instance, name: string): any
	local module = entry:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then return nil end

	local loaded, value = pcall(require, module)

	return if loaded then value else nil
end

local function profileOf(name: string): Profile?
	local cached = profiles[name]
	if cached ~= nil then return cached or nil end

	local library = find(ReplicatedStorage, Config.Library)
	local entry = library and library:FindFirstChild(name)
	local settings: MobTypes.Footsteps? = entry and requireChild(entry, Config.ConfigKey)
	local animations = entry and requireChild(entry, "animations")
	local folder = find(ReplicatedStorage, Config.Animations)
	local published = folder and folder:FindFirstChild(name)
	local gaits: { [string]: Gait } = {}
	local usable = false

	if settings and typeof(settings.gaits) == "table" and typeof(animations) == "table" then
		for key, gait in settings.gaits do
			local clip = animations[key]
			if typeof(clip) ~= "string" then continue end

			local entryGait: Gait = { Settings = gait, Ids = {}, Names = { [clip] = true } }
			local animation = published and published:FindFirstChild(clip)

			if animation and animation:IsA("Animation") then
				entryGait.Ids[animation.AnimationId] = true
			end

			gaits[key] = entryGait
			usable = true
		end
	end

	if not settings or not usable then
		profiles[name] = false
		return nil
	end

	local profile: Profile = { Settings = settings, Gaits = gaits }

	profiles[name] = profile

	return profile
end

local function gaitTracks(model: Model, profile: Profile): { [string]: AnimationTrack }
	local found: { [string]: AnimationTrack } = {}
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then return found end

	for _, track in animator:GetPlayingAnimationTracks() do
		local animation = track.Animation
		if not animation then continue end

		for key, gait in profile.Gaits do
			if gait.Ids[animation.AnimationId] or gait.Names[animation.Name] then
				found[key] = track
				break
			end
		end
	end

	return found
end

local function rescan(origin: Vector3)
	local live = find(workspace, Config.Live)
	local models: { Instance } = if live then live:GetChildren() else {}
	local seen: { [Model]: boolean } = {}

	for _, model in models do
		if not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then continue end

		local profile = profileOf(model.Name)
		local root = model.PrimaryPart

		if not profile or not root or (root.Position - origin).Magnitude > profile.Settings.range then continue end

		local watch: Watch = watched[model] or { Root = root, Profile = profile, Strides = {} }
		local strides: { [string]: Stride } = {}

		for key, track in gaitTracks(model, profile) do
			local kept = watch.Strides[key]
			strides[key] = if kept and kept.Track == track then kept else { Track = track }
		end

		watch.Root = root
		watch.Strides = strides
		watched[model] = watch
		seen[model] = true
	end

	for model in watched do
		if not seen[model] then
			watched[model] = nil
		end
	end
end

local function crossed(at: number, from: number, to: number): boolean
	if to >= from then return at > from and at <= to end

	return at > from or at <= to
end

local function struck(stride: Stride, gait: MobTypes.Gait, minWeight: number): boolean
	local track = stride.Track

	if not track.IsPlaying or track.Length <= 0 then
		stride.Last = nil
		return false
	end

	local phase = (track.TimePosition % track.Length) / track.Length
	local last = stride.Last

	stride.Last = phase

	if not last or track.WeightCurrent < minWeight then return false end

	for _, at in gait.at do
		if crossed(at, last, phase) then return true end
	end

	return false
end

local function stepOf(watch: Watch): string?
	local heaviest, shape = -1, nil

	for key, stride in watch.Strides do
		local gait = watch.Profile.Gaits[key]

		if gait and struck(stride, gait.Settings, watch.Profile.Settings.min_weight) and stride.Track.WeightCurrent > heaviest then
			heaviest, shape = stride.Track.WeightCurrent, gait.Settings.shake
		end
	end

	return shape
end

local function step()
	local character = Players.LocalPlayer.Character
	local own = character and character.PrimaryPart
	if not own then return end

	local now = os.clock()

	if now >= rescanAt then
		rescanAt = now + Config.Rescan
		rescan(own.Position)
	end

	local strongest, shape = 0, nil

	for _, watch in watched do
		local stepped = stepOf(watch)
		if not stepped then continue end

		local scale = 1 - (watch.Root.Position - own.Position).Magnitude / watch.Profile.Settings.range

		if scale > strongest then
			strongest, shape = scale, stepped
		end
	end

	if not shape then return end

	cameraHandler = cameraHandler or Jloader.GetHandler("CameraHandler")

	if cameraHandler and cameraHandler.Shake then
		cameraHandler:Shake(shape, strongest)
	end
end

function StepShakeHandler:Load()
	RunService.PreRender:Connect(step)
end

return StepShakeHandler
