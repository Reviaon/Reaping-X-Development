local AimLine = require("./AimLine")
local Config = require("./Config")
local Sidestep = require("./Sidestep")

local Draw = {}

local function roll(range): number
	if typeof(range) == "number" then return range end

	return range[1] + math.random() * (range[2] - range[1])
end

local function aiming(target: Model?): boolean
	local watch = Config.Projectile
	return target ~= nil and watch.Phases[target:GetAttribute(watch.StateAttribute)] == true
end

local function close(mob, window)
	if window.Passed then return end

	local seen = string.format("%.2f", window.SeenAt - window.Since)

	if window.Cooling then
		Sidestep.Report(mob, "was aimed at while its sidestep was cooling down")
	elseif window.Busy then
		Sidestep.Report(mob, `was aimed at for {seen}s, but was busy in {window.Busy}`)
	else
		Sidestep.Report(mob, `was aimed at for {seen}s, short of its {string.format("%.2f", window.React)}s read`)
	end
end

function Draw.Line(mob, settings)
	local archer = mob:TargetRoot()
	if not archer or not aiming(mob:GetTarget()) then return nil end

	local line = AimLine.Of(archer)

	return if line and AimLine.Touches(line, mob, settings) then line else nil
end

function Draw.Incoming(mob): boolean
	local settings = Sidestep.Settings(mob)
	if not settings then return false end

	local blackboard = mob.Blackboard
	local now = os.clock()
	local window = blackboard.AimWindow
	local line = Draw.Line(mob, settings)

	if window and (not aiming(mob:GetTarget()) or now - window.SeenAt > Config.Projectile.WindowGap) then
		close(mob, window)
		window = nil
		blackboard.AimWindow = nil
	end

	if not line then return false end

	if not window then
		window = { Since = now, React = roll(settings.react) }
		blackboard.AimWindow = window
	end

	window.SeenAt = now

	if window.Passed then return false end

	if not Sidestep.Ready(mob, now) then
		window.Cooling = true
		return false
	end

	window.Cooling = nil

	if now - window.Since < window.React then return false end

	if not Sidestep.Free(mob, settings) then
		window.Busy = mob.Machine.Name
		return false
	end

	window.Passed = true

	local read = string.format("%.2f", now - window.Since)

	if math.random() > settings.chance then
		Sidestep.Report(mob, `read the draw after {read}s and let it go`)
		return false
	end

	Sidestep.Commit(mob, line, settings, now)
	Sidestep.Report(mob, `read the draw after {read}s and sidestepped`)

	return true
end

return Draw
