--[[@
	**RecoveryService**: plays the universal get-up clip on the local character after whatever put it down
	- **Play(character, source):** fades in by the source's `Config.Sources` entry and holds the get-up status until the clip releases
	  - Returns the track and the seconds the lock lasts; nil and 0 when the clip, the source or the character is missing
	- **Triggers:**
	  - `Ragdoll`: `Start` watches the local character's `RagdollService` status end, alive and not a morph
	  - `TackleMiss`: `TackleAttackComponent` hands over at its get-up time
	- **Client only:** the owner plays it and the Animator replicates it to everyone
	- **Observers:** the ragdoll pose stream carries joint rotations only, so its after-exit tail would hold the clip at standing height
	  - `Start` sets `TailAttribute` to `Tail` on the local character, so the stream hands observers to their own copy of the clip at exit
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimatorService = require("./AnimatorService")
local StatusService = require("./StatusService")
local RagdollService = require("../Combat/RagdollService")

local Config = require("@self/Config")
local Types = require("@self/Types")

type Source = Types.Source

local RecoveryService = {
	Settings = Config,
}

local tracks: { [Model]: AnimationTrack } = {}
local started = false

local function isMorph(character: Model): boolean
	return require(script.Parent.Parent).CharacterService.MorphOf(character) ~= nil
end

local function alive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function RecoveryService.Stop(character: Model, fade: number?)
	local track = tracks[character]
	tracks[character] = nil

	if track and track.IsPlaying then
		track:Stop(fade or Config.FadeOut)
	end

	StatusService:RemoveStatus(character, Config.Status, Config.StatusSource)
end

function RecoveryService.Play(character: Model, source: string): (AnimationTrack?, number)
	local entry: Source? = Config.Sources[source]
	if not entry or not alive(character) or not AnimatorService:HasAnimation(Config.Animation) then return nil, 0 end

	RecoveryService.Stop(character, 0)

	local track = AnimatorService:GetTrack(character, Config.Animation)
	if not track then return nil, 0 end

	local speed = entry.Speed or Config.Speed

	track.Priority = Config.Priority
	track.Looped = false
	track:Play(entry.FadeIn, 1, speed)

	local length = if track.Length > 0 then track.Length / speed else Config.FallbackLength
	local hold = math.max(length - Config.Release, 0)

	tracks[character] = track
	track.Stopped:Once(function()
		if tracks[character] == track then
			tracks[character] = nil
		end
	end)

	StatusService:SetStatus(character, Config.Status, true, hold, Config.StatusSource)

	return track, hold
end

function RecoveryService.IsRecovering(character: Model): boolean
	return tracks[character] ~= nil
end

local function watch(character: Model)
	local was = RagdollService.IsRagdolled(character)

	character:SetAttribute(Config.TailAttribute, Config.Tail)

	character:GetAttributeChangedSignal(RagdollService.Settings.Status):Connect(function()
		local now = RagdollService.IsRagdolled(character)
		if now == was then return end

		was = now

		if now then
			RecoveryService.Stop(character, 0)
		elseif not isMorph(character) then
			RecoveryService.Play(character, "Ragdoll")
		end
	end)
end

function RecoveryService.Start()
	if started or not RunService:IsClient() then return end

	started = true

	local player = Players.LocalPlayer

	if player.Character then
		watch(player.Character)
	end

	player.CharacterAdded:Connect(watch)
end

return RecoveryService
