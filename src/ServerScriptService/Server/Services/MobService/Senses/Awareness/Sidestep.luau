local AimLine = require("./AimLine")
local Config = require("./Config")

local Sidestep = {}

function Sidestep.Settings(mob)
	local dash = mob.Config.dash
	return dash and dash.sidestep or nil
end

function Sidestep.Report(mob, text: string)
	local debug = mob.Services.DebugService

	if debug and debug.IsEnabled() then
		print(`{Config.Projectile.LogPrefix} {mob.Name} {text}`)
	end
end

function Sidestep.Ready(mob, now: number): boolean
	return now >= (mob.Blackboard.SidestepReadyAt or 0)
end

function Sidestep.Free(mob, settings): boolean
	local machine = mob.Machine
	if not machine:IsLocked() then return true end

	return table.find(settings.interrupts or {}, machine.Name) ~= nil
end

function Sidestep.Commit(mob, line, settings, now: number)
	local blackboard = mob.Blackboard
	local window = blackboard.AimWindow

	blackboard.SidestepReadyAt = now + settings.cooldown
	blackboard.Sidestep = line

	if window then
		window.Passed = true
	end
end

function Sidestep.Point(mob): Vector3?
	local settings = Sidestep.Settings(mob)
	local line = mob.Blackboard.Sidestep

	mob.Blackboard.Sidestep = nil

	if not settings or not line then return nil end

	return AimLine.Clear(line, mob, settings)
end

return Sidestep
