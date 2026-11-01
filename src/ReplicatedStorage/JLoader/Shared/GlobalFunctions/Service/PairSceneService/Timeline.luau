local AnimationClipProvider = game:GetService("AnimationClipProvider")
local RunService = game:GetService("RunService")

local DebugService = require("../DebugService")
local Signal = require("../../Signal")

local Timeline = {}

local cache = {}
local waiting = {}

local function read(clip: Instance)
	local markers, length = {}, 0

	if clip:IsA("KeyframeSequence") then
		for _, keyframe in clip:GetKeyframes() do
			length = math.max(length, keyframe.Time)

			for _, marker in keyframe:GetMarkers() do
				table.insert(markers, { Time = keyframe.Time, Name = marker.Name })
			end
		end
	else
		for _, curve in clip:GetDescendants() do
			if curve:IsA("MarkerCurve") then
				for _, marker in curve:GetMarkers() do
					length = math.max(length, marker.Time)
					table.insert(markers, { Time = marker.Time, Name = marker.Value })
				end
			elseif curve:IsA("FloatCurve") or curve:IsA("RotationCurve") then
				for _, key in curve:GetKeys() do
					length = math.max(length, key.Time)
				end
			end
		end
	end

	table.sort(markers, function(a, b)
		return a.Time < b.Time
	end)

	return { Length = length, Markers = markers }
end

function Timeline.Load(animation: Animation, callback: (data: { Length: number, Markers: { any } }) -> ())
	local id = animation.AnimationId
	local data = cache[id]

	if data then
		callback(data)
		return
	end

	if waiting[id] then
		table.insert(waiting[id], callback)
		return
	end

	waiting[id] = { callback }

	task.spawn(function()
		local loaded, clip = pcall(AnimationClipProvider.GetAnimationClipAsync, AnimationClipProvider, id)
		local result = if loaded and clip then read(clip) else { Length = 0, Markers = {} }

		if not loaded and DebugService.IsEnabled() then
			warn(`[PairScene] could not read {animation.Name} ({id}): {clip}`)
		end

		if loaded then
			cache[id] = result
		end

		local callbacks = waiting[id]
		waiting[id] = nil

		for _, queued in callbacks do
			queued(result)
		end
	end)
end

function Timeline.Play(animation: Animation, looped: boolean, position: number?)
	local track = {
		Animation = animation,
		Looped = looped,
		Length = 0,
		TimePosition = position or 0,
		IsPlaying = true,
		Stopped = Signal.new(),
	}

	local signals = {}
	local data = nil
	local clock = position or 0
	local last = if clock > 0 then clock else -math.huge
	local connection

	function track:GetMarkerReachedSignal(name: string)
		signals[name] = signals[name] or Signal.new()
		return signals[name]
	end

	function track:Stop()
		if not track.IsPlaying then return end

		track.IsPlaying = false

		if connection then
			connection:Disconnect()
			connection = nil
		end

		track.Stopped:Fire()
	end

	local function reach(from: number, to: number)
		for _, marker in data.Markers do
			if not track.IsPlaying then return end

			local signal = signals[marker.Name]

			if signal and marker.Time > from and marker.Time <= to then
				signal:Fire(marker.Name)
			end
		end
	end

	local function advance()
		local length = data.Length

		if length <= 0 then
			track:Stop()
			return
		end

		while looped and clock >= length and track.IsPlaying do
			reach(last, length)
			clock -= length
			last = -math.huge
		end

		local now = math.min(clock, length)

		reach(last, now)
		last = now
		track.TimePosition = now

		if not looped and clock >= length then
			track:Stop()
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		clock += dt

		if data then
			advance()
		end
	end)

	task.defer(Timeline.Load, animation, function(loaded)
		if not track.IsPlaying then return end

		data = loaded
		track.Length = loaded.Length
		advance()
	end)

	return track
end

return Timeline
