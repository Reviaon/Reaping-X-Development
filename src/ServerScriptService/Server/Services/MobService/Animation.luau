local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Animation = {}
Animation.__index = Animation

Animation.Settings = {
	FolderName = "Mobs",
	SavesName = "AnimSaves",
	IdleThreshold = 0.75,
	RunHysteresis = 2,
	PlaybackRange = { 0.6, 1.4 },
	PlaybackEpsilon = 0.05,
	LocomotionFade = 0.4,
	ExclusiveFade = 0.15,
	ActionFade = 0.1,
	CullFade = 0.3,
}

local resolved = {}
local warned = {}

local function mobsFolder(): Instance?
	local storage = ReplicatedStorage:FindFirstChild("Storage")
	local animations = storage and storage:FindFirstChild("Animations")
	return animations and animations:FindFirstChild(Animation.Settings.FolderName)
end

local function fromSaves(kind, name: string)
	if not RunService:IsStudio() then return nil end

	local saves = kind.Template:FindFirstChild(Animation.Settings.SavesName)
	local sequence = saves and saves:FindFirstChild(name)
	if not sequence or not sequence:IsA("KeyframeSequence") then return nil end

	local registered, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, sequence)
	if not registered then return nil end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = id

	return animation
end

local function resolve(kind, name: string)
	local cache = resolved[kind.Name]

	if not cache then
		cache = {}
		resolved[kind.Name] = cache
	end

	local cached = cache[name]
	if cached ~= nil then return cached or nil end

	local folder = mobsFolder()
	local published = folder and folder:FindFirstChild(kind.Name)
	local animation = published and published:FindFirstChild(name)

	if not animation or not animation:IsA("Animation") or not string.match(animation.AnimationId, "%d") then
		animation = fromSaves(kind, name)
	end

	cache[name] = animation or false

	if not animation and not warned[kind.Name .. name] then
		warned[kind.Name .. name] = true
		warn(`[MobService] {kind.Name} has no animation "{name}" under Storage.Animations.{Animation.Settings.FolderName}.{kind.Name}.`)
	end

	return animation
end

function Animation.new(mob)
	return setmetatable({
		Mob = mob,
		Animator = mob.Humanoid:FindFirstChildOfClass("Animator"),
		Tracks = {},
		ClearAt = {},
		Locomotion = nil,
		Culled = false,
	}, Animation)
end

function Animation:Track(key: string): AnimationTrack?
	local track = self.Tracks[key]
	if track then return track end

	local name = self.Mob.Config.animations and self.Mob.Config.animations[key]
	if not name or not self.Animator then return nil end

	local animation = resolve(self.Mob.Kind, name)
	if not animation then return nil end

	track = self.Animator:LoadAnimation(animation)
	self.Tracks[key] = track

	return track
end

function Animation:PlayAction(key: string, speed: number?, position: number?): AnimationTrack?
	if self.Culled then return nil end

	local track = self:Track(key)
	if not track then return nil end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(Animation.Settings.ActionFade, 1, speed or 1)

	if position then
		track.TimePosition = position
	end

	return track
end

function Animation:Position(key: string): number?
	local track = self.Tracks[key]
	return if track and track.IsPlaying then track.TimePosition else nil
end

function Animation:Stop(key: string, fade: number?)
	local track = self.Tracks[key]

	if track and track.IsPlaying then
		fade = fade or Animation.Settings.ActionFade
		track:Stop(fade)
		self.ClearAt[key] = os.clock() + fade
	end
end

local function partnersOf(config, key: string): { string }
	local partners = {}

	for _, pair in config.animation_exclusive or {} do
		if pair[1] == key then
			table.insert(partners, pair[2])
		elseif pair[2] == key then
			table.insert(partners, pair[1])
		end
	end

	return partners
end

function Animation:Blocked(key: string): boolean
	local now = os.clock()
	local fade = Animation.Settings.ExclusiveFade
	local blocked = false

	for _, partner in partnersOf(self.Mob.Config, key) do
		local track = self.Tracks[partner]
		local clearAt = self.ClearAt[partner] or 0

		if track and (track.IsPlaying or clearAt > now + fade) then
			track:Stop(fade)
			clearAt = now + fade
			self.ClearAt[partner] = clearAt
		end

		if clearAt > now then
			blocked = true
		end
	end

	return blocked
end

function Animation:StopAll(fade: number?)
	for _, track in self.Tracks do
		if track.IsPlaying then
			track:Stop(fade or Animation.Settings.CullFade)
		end
	end

	self.Locomotion = nil
end

local PLAYBACK_REFERENCE = {
	Walk = "walk_speed",
	WalkLeft = "walk_speed",
	WalkRight = "walk_speed",
	WalkBack = "walk_speed",
	Run = "run_speed",
}

local function forwardKey(config, speed: number, current: string?): string
	local midpoint = (config.walk_speed + config.run_speed) / 2
	local margin = if current == "Run" then -Animation.Settings.RunHysteresis else Animation.Settings.RunHysteresis

	return if speed >= midpoint + margin then "Run" else "Walk"
end

local function locomotionKey(mob, planar: Vector3, current: string?): string
	local speed = planar.Magnitude
	local config = mob.Config

	if speed < Animation.Settings.IdleThreshold then return "Idle" end

	local relative = mob.Root.CFrame:VectorToObjectSpace(planar)
	local forward, side = -relative.Z, relative.X
	local key

	if forward >= math.abs(side) then
		key = forwardKey(config, speed, current)
	elseif -forward >= math.abs(side) then
		key = "WalkBack"
	else
		key = if side > 0 then "WalkRight" else "WalkLeft"
	end

	if config.animations[key] == nil then
		return "Walk"
	end

	return key
end

local function playbackSpeed(config, key: string, speed: number): number
	local reference = PLAYBACK_REFERENCE[key] and config[PLAYBACK_REFERENCE[key]]
	if not reference or reference <= 0 then return 1 end

	local range = Animation.Settings.PlaybackRange

	return math.clamp(speed / reference, range[1], range[2])
end

function Animation:UpdateLocomotion()
	if self.Culled then return end

	local mob = self.Mob
	local velocity = mob.Root.AssemblyLinearVelocity
	local planar = Vector3.new(velocity.X, 0, velocity.Z)
	local key = locomotionKey(mob, planar, self.Locomotion)

	if key ~= self.Locomotion then
		local blocked = self:Blocked(key)

		if self.Locomotion then
			self:Stop(self.Locomotion, Animation.Settings.LocomotionFade)
			self.Locomotion = nil
		end

		if blocked then return end

		self.Locomotion = key

		local track = self:Track(key)

		if track then
			track.Priority = if key == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			track.Looped = true
			track:Play(Animation.Settings.LocomotionFade)
		end
	end

	local track = self.Tracks[key]
	if not track then return end

	local speed = playbackSpeed(mob.Config, key, planar.Magnitude)

	if math.abs(track.Speed - speed) > Animation.Settings.PlaybackEpsilon then
		track:AdjustSpeed(speed)
	end
end

function Animation:SetCulled(culled: boolean)
	if self.Culled == culled then return end

	self.Culled = culled

	if culled then
		self:StopAll()
	end
end

function Animation:Destroy()
	for _, track in self.Tracks do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.Tracks)
	self.Locomotion = nil
end

return Animation
