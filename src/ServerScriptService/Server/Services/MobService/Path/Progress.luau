local Geometry = require("./Geometry")

local Progress = {}

function Progress.Stuck(nav, position: Vector3, now: number, settings): boolean
	local last = nav.StuckFrom

	if not last or Geometry.Planar(position, last) >= settings.stuck_step then
		nav.StuckFrom = position
		nav.StuckSince = now
	end

	return now - nav.StuckSince >= settings.stuck_time
end

function Progress.Unstick(nav, position: Vector3, now: number)
	nav.StuckFrom = position
	nav.StuckSince = now
end

function Progress.Attempt(nav, target: Model, distance: number, settings): boolean
	local track = nav.Attempts

	if not track or track.Target ~= target or distance < track.Best - settings.stuck_step then
		nav.Attempts = { Target = target, Best = distance, Count = 0 }
		return false
	end

	track.Count += 1

	return track.Count >= settings.attempts
end

function Progress.Reset(nav)
	nav.Attempts = nil
end

return Progress
