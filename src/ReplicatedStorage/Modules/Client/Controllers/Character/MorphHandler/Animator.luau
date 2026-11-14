local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("./Config")
local Types = require("./Types")

local Animator = {}
Animator.__index = Animator

type Fields = {
	Name: string,
	Map: { [string]: string },
	Mob: string,
	Animator: Animator?,
	Folder: Instance?,
	Tracks: { [string]: AnimationTrack },
	Warned: { [string]: boolean },
}

type Self = typeof(setmetatable({} :: Fields, Animator))

local function folderFor(mob: string): Instance?
	local found: Instance? = ReplicatedStorage

	for _, segment in Config.AnimationFolder do
		found = if found then found:FindFirstChild(segment) else nil
	end

	return if found then found:FindFirstChild(mob) else nil
end

function Animator.new(session: Types.Session): Types.ClipPlayer
	local humanoid = session.Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)

	local self: Fields = {
		Name = session.Name,
		Map = session.Profile.animations,
		Mob = session.Profile.mob,
		Animator = if animator and animator:IsA("Animator") then animator else nil,
		Folder = folderFor(session.Profile.mob),
		Tracks = {},
		Warned = {},
	}

	return setmetatable(self, Animator) :: any
end

function Animator.Track(self: Self, key: string): AnimationTrack?
	local track = self.Tracks[key]
	if track then return track end

	local name = self.Map[key] or key
	local animation = if self.Folder then self.Folder:FindFirstChild(name) else nil
	local animator = self.Animator

	if not animation or not animation:IsA("Animation") or not animator then
		if not self.Warned[key] then
			self.Warned[key] = true
			warn(`[MorphHandler] {self.Name} has no clip "{name}" under Storage.Animations.Mobs.{self.Mob}.`)
		end

		return nil
	end

	local loaded = animator:LoadAnimation(animation)
	self.Tracks[key] = loaded

	return loaded
end

function Animator.Play(self: Self, key: string, speed: number?): AnimationTrack?
	local track = Animator.Track(self, key)
	if not track then return nil end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(Config.ActionFade, 1, speed or 1)

	return track
end

function Animator.Crossfade(self: Self, from: string, to: string, speed: number?, fade: number?): AnimationTrack?
	local playing = Animator.Playing(self, from)
	local position = if playing then playing.TimePosition else 0

	Animator.Stop(self, from, fade)

	local track = Animator.Play(self, to, speed)

	if track then
		track.TimePosition = position
	end

	return track
end

function Animator.Loop(self: Self, key: string, priority: Enum.AnimationPriority): AnimationTrack?
	local track = Animator.Track(self, key)
	if not track then return nil end

	track.Priority = priority
	track.Looped = true
	track:Play(Config.LocomotionFade)

	return track
end

function Animator.Playing(self: Self, key: string): AnimationTrack?
	local track = self.Tracks[key]
	return if track and track.IsPlaying then track else nil
end

function Animator.Stop(self: Self, key: string?, fade: number?)
	local track = if key then self.Tracks[key] else nil

	if track and track.IsPlaying then
		track:Stop(fade or Config.ActionFade)
	end
end

function Animator.StopAll(self: Self, fade: number?)
	for _, track in self.Tracks do
		if track.IsPlaying then
			track:Stop(fade or Config.ActionFade)
		end
	end
end

function Animator.Destroy(self: Self)
	for _, track in self.Tracks do
		track:Stop(0)
		track:Destroy()
	end

	table.clear(self.Tracks)
end

return Animator
