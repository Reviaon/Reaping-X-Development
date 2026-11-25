local SoundService = game:GetService("SoundService")

local Config = require("./Config")
local Groups = require("./Groups")
local Registry = require("./Registry")
local SoundTypes = require("../SoundTypes")

local Emitter = {}

function Emitter.Create(Path: string, Entry: SoundTypes.Entry, Id: number, Options: SoundTypes.PlayOptions): (Sound, Instance?)
	local Defaults = Config.Defaults
	local Trim = Entry.Trim

	local Looped = Options.Looped
	if Looped == nil then
		Looped = Entry.Looped == true
	end

	local Sound = Instance.new("Sound")
	Sound.Name = Path
	Sound.SoundId = Registry.ContentId(Id)
	Sound.Volume = Options.Volume or Entry.Volume or Defaults.Volume
	Sound.PlaybackSpeed = Options.PlaybackSpeed or Entry.PlaybackSpeed or Defaults.PlaybackSpeed
	Sound.Looped = Looped
	Sound.TimePosition = Options.StartAt or (Trim and Trim[Id]) or Entry.StartAt or 0
	Sound.RollOffMinDistance = Defaults.RollOffMinDistance
	Sound.RollOffMaxDistance = Entry.RollOffMaxDistance or Defaults.RollOffMaxDistance
	Sound.SoundGroup = Groups.Get(Registry.Category(Path))

	local Position = Options.Position
	if Position then
		local Holder = Instance.new("Attachment")
		Holder.Name = Path
		Holder.WorldPosition = Position
		Holder.Parent = workspace.Terrain
		Sound.Parent = Holder
		return Sound, Holder
	end

	Sound.Parent = Options.Parent or SoundService
	return Sound, nil
end

return Emitter
