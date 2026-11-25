local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local SoundTypes = require("./SoundTypes")
local Registry = require("@self/Registry")
local Emitter = require("@self/Emitter")
local Tracker = require("@self/Tracker")
local Groups = require("@self/Groups")

local SoundService = {}

local function Targets(Target: SoundTypes.Target): { Sound }
	if typeof(Target) == "Instance" then
		return { Target :: Sound }
	elseif type(Target) == "string" then
		return Tracker.Find(Target :: string)
	end
	return Target :: { Sound }
end

local function OwnerOf(Parent: Instance?): Instance?
	if not Parent then
		return nil
	end
	return if Parent:IsA("Model") then Parent else Parent:FindFirstAncestorOfClass("Model")
end

local function Apply(Subject: Instance, Properties: { [string]: any }, Fade: number?): Tween?
	if Fade and Fade > 0 then
		local Tween = TweenService:Create(Subject, TweenInfo.new(Fade), Properties)
		Tween:Play()
		return Tween
	end

	for Property, Value in Properties do
		(Subject :: any)[Property] = Value
	end
	return nil
end

function SoundService:Get(Path: string): SoundTypes.Entry?
	return Registry.Get(Path)
end

function SoundService:Has(Path: string): boolean
	return Registry.Get(Path) ~= nil
end

function SoundService:TryPlay(Path: string?, Options: SoundTypes.PlayOptions?): Sound?
	if not Path or not Registry.Get(Path) then
		return nil
	end
	return self:Play(Path, Options)
end

function SoundService:Paths(Prefix: string?): { string }
	return Registry.List(Prefix)
end

function SoundService:Ids(Path: string): { string }
	return Registry.Ids(Path)
end

function SoundService:Play(Path: string, Options: SoundTypes.PlayOptions?): Sound?
	local Entry = Registry.Get(Path)
	if not Entry then
		warn(`[SoundService]: No sound at '{Path}'.`)
		return nil
	end

	local Settings: SoundTypes.PlayOptions = Options or {}
	local Id = Registry.Pick(Path, Settings.Variant, Settings.Owner or OwnerOf(Settings.Parent), Settings.Number)
	if not Id then
		warn(`[SoundService]: '{Path}' has no ids.`)
		return nil
	end

	local Sound, Holder = Emitter.Create(Path, Entry, Id, Settings)
	Tracker.Add(Sound, Path, Holder)

	local FadeIn = Settings.FadeIn
	if FadeIn and FadeIn > 0 then
		local Volume = Sound.Volume
		Sound.Volume = 0
		Apply(Sound, { Volume = Volume }, FadeIn)
	end

	Sound:Play()
	return Sound
end

function SoundService:Find(Prefix: string?, Scope: Instance?): { Sound }
	return Tracker.Find(Prefix, Scope)
end

function SoundService:IsPlaying(Target: SoundTypes.Target): boolean
	for _, Sound in Targets(Target) do
		if Sound.IsPlaying then
			return true
		end
	end
	return false
end

function SoundService:Stop(Target: SoundTypes.Target, Fade: number?)
	for _, Sound in Targets(Target) do
		local Tween = Apply(Sound, { Volume = 0 }, Fade)

		if Tween then
			Tween.Completed:Once(function()
				Tracker.Release(Sound)
			end)
		else
			Tracker.Release(Sound)
		end
	end
end

function SoundService:StopAll(Scope: Instance?, Fade: number?)
	self:Stop(Tracker.Find(nil, Scope), Fade)
end

function SoundService:Pause(Target: SoundTypes.Target)
	for _, Sound in Targets(Target) do
		Sound:Pause()
	end
end

function SoundService:Resume(Target: SoundTypes.Target)
	for _, Sound in Targets(Target) do
		Sound:Resume()
	end
end

function SoundService:Tune(Target: SoundTypes.Target, Tuning: SoundTypes.Tuning, Fade: number?)
	local Properties = {}
	if Tuning.Volume then
		Properties.Volume = Tuning.Volume
	end
	if Tuning.PlaybackSpeed then
		Properties.PlaybackSpeed = Tuning.PlaybackSpeed
	end

	for _, Sound in Targets(Target) do
		Apply(Sound, Properties, Fade)
	end
end

function SoundService:TuneGroup(Category: string, Volume: number, Fade: number?)
	local Group = Groups.Get(Category)
	if Group then
		Apply(Group, { Volume = Volume }, Fade)
	end
end

function SoundService:PreloadList(Prefix: string?): { Sound }
	local Seen: { [string]: boolean } = {}
	local List = {}

	for _, Path in Registry.List(Prefix) do
		for _, Id in Registry.Ids(Path) do
			if not Seen[Id] then
				Seen[Id] = true

				local Sound = Instance.new("Sound")
				Sound.Name = Path
				Sound.SoundId = Id
				table.insert(List, Sound)
			end
		end
	end
	return List
end

function SoundService:Preload(Prefix: string?): number
	local Failed = 0

	ContentProvider:PreloadAsync(self:PreloadList(Prefix), function(AssetId: string, Status: Enum.AssetFetchStatus)
		if Status ~= Enum.AssetFetchStatus.Success then
			Failed += 1
			warn(`[SoundService]: Failed to preload '{AssetId}' ({Status.Name})`)
		end
	end)
	return Failed
end

return SoundService
