local Config = require("./Config")
local Weapon = require("./Weapon")
local Aim = require("./Aim")
local Shot = require("./Shot")

local Cycle = {}

local function stopTrack(state, key: string, fade: number)
	local track = state.tracks[key]
	if not track then return end

	if track.IsPlaying then
		track:Stop(fade)
	end

	state.tracks[key] = nil
end

local function play(controller, state, id: string, projectile, key: string, loop: boolean, fade: number): number
	local track = controller.AnimatorService:PlayTrack(controller.Character, Weapon.AnimationName(id, projectile, key), {
		Priority = Config.Priority,
		FadeTime = fade,
		Loop = loop,
	})

	state.tracks[key] = track

	return if track.Length > 0 then track.Length else Config.FallbackLength
end

local function broadcast(controller, state)
	local relay = controller.RangedRelay

	if relay then
		relay.AimState:Fire(state.phase, state.nocked)
	end
end

local function markerName(projectile, key: string): string?
	local markers = projectile.markers
	local name = typeof(markers) == "table" and markers[key]
	return if typeof(name) == "string" then name else nil
end

local function watch(state, key: string, name: string?, flag: string)
	local track = state.tracks[key]
	if not name or not track then return end

	state[flag] = false
	state.markerConnection = track:GetMarkerReachedSignal(name):Connect(function()
		state[flag] = true
	end)
end

local function release(controller, state, projectile)
	state.released = true
	state.nocked = false

	Aim.Release(projectile)
	Shot.Fire(controller, state, projectile)
end

function Cycle.StopTracks(state, fade: number)
	for key in state.tracks do
		stopTrack(state, key, fade)
	end
end

function Cycle.Unwatch(state)
	if state.markerConnection then
		state.markerConnection:Disconnect()
		state.markerConnection = nil
	end

	state.releaseMarked = nil
	state.nockMarked = nil
end

function Cycle.Enter(controller, state, phase: string)
	local id, projectile = Weapon.Of(controller)
	if not projectile then return end

	local fades = Config.Fades

	Cycle.Unwatch(state)

	state.phase = phase
	state.phaseStart = os.clock()
	state.clipLength = math.huge

	if phase == "Drawing" then
		stopTrack(state, "reload", fades.Draw)
		state.clipLength = play(controller, state, id, projectile, "draw", false, fades.Draw)
		Aim.HoldFov(projectile, true)
	elseif phase == "Holding" then
		play(controller, state, id, projectile, "hold", true, fades.Hold)
		stopTrack(state, "draw", fades.Hold)
	elseif phase == "Firing" then
		state.released = false
		state.clipLength = play(controller, state, id, projectile, "fire", false, fades.Fire)
		stopTrack(state, "hold", fades.Fire)
		stopTrack(state, "draw", fades.Fire)
		watch(state, "fire", markerName(projectile, "release"), "releaseMarked")
	elseif phase == "Reloading" then
		state.clipLength = play(controller, state, id, projectile, "reload", false, fades.Reload)
		stopTrack(state, "fire", fades.Reload)
		watch(state, "reload", markerName(projectile, "nock"), "nockMarked")
	end

	local handover = Config.NextFade[phase]
	state.phaseLength = math.max(0, state.clipLength - (if handover then fades[handover] else 0))

	broadcast(controller, state)
end

function Cycle.Finish(controller, state)
	Cycle.Unwatch(state)
	Cycle.StopTracks(state, Config.Fades.Stop)

	state.phase = "Idle"
	state.held = false
	state.queued = false
	state.aimPoint = nil
	state.aimPitch = nil

	if state.savedAutoRotate ~= nil and controller.Humanoid then
		controller.Humanoid.AutoRotate = state.savedAutoRotate
	end

	state.savedAutoRotate = nil
	Aim.HoldFov(nil, false)

	if controller.Character then
		controller.StatusService:RemoveStatus(controller.Character, Config.Status)
	end

	if state.combat and state.combat.CurrentBranch == "Projectile" then
		state.combat.CurrentBranch = "Neutral"
	end

	broadcast(controller, state)
end

function Cycle.Advance(controller, state, projectile)
	local elapsed = os.clock() - state.phaseStart
	local releaseReady = if state.releaseMarked ~= nil then state.releaseMarked else elapsed >= (projectile.release_at or 0)

	if state.phase == "Firing" and not state.released and releaseReady then
		release(controller, state, projectile)
	end

	if elapsed < state.phaseLength then return end

	if state.phase == "Drawing" then
		Cycle.Enter(controller, state, if state.queued then "Firing" else "Holding")
		state.queued = false
	elseif state.phase == "Firing" then
		if not state.released then
			release(controller, state, projectile)
		end

		if state.held then
			Cycle.Enter(controller, state, "Reloading")
		else
			Cycle.Finish(controller, state)
		end
	elseif state.phase == "Reloading" then
		state.nocked = true

		if state.held then
			Cycle.Enter(controller, state, "Drawing")
		else
			Cycle.Finish(controller, state)
		end
	end
end

return Cycle
