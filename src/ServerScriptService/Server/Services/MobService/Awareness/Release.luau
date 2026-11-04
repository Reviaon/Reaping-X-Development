local AimLine = require("./AimLine")
local Sidestep = require("./Sidestep")

local Release = {}

function Release.React(mobs, archer: Model, origin: Vector3, direction: Vector3)
	local line = AimLine.FromRay(origin, direction)
	if not line then return end

	local now = os.clock()

	for mob in mobs do
		local settings = Sidestep.Settings(mob)
		local release = settings and settings.release

		if not release or mob.Dead or not mob.Root or mob:GetTarget() ~= archer then continue end
		if not AimLine.Touches(line, mob, settings) then continue end

		if not Sidestep.Ready(mob, now) then
			Sidestep.Report(mob, "saw the release while its sidestep was cooling down")
			continue
		end

		if mob:IsDisabled() or not Sidestep.Free(mob, settings) then
			Sidestep.Report(mob, `saw the release, but was busy in {mob.Machine.Name}`)
			continue
		end

		if math.random() > release.chance then
			Sidestep.Report(mob, "saw the release and held its ground")
			continue
		end

		Sidestep.Commit(mob, line, settings, now)

		if typeof(release.dodge) == "number" and release.dodge > 0 then
			mob.Services.ProjectileService.MarkDodge(mob.Model, release.dodge)
		end

		mob.Machine:Request("Dash", { kind = "sidestep" }, true)
		Sidestep.Report(mob, "saw the release and sidestepped")
	end
end

return Release
