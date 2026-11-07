local Shot = require("./Shot")
local ProjectileService = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Combat/ProjectileService")
local AimLineService = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Combat/AimLineService")

local Line = {}

local function lineFor(state, style: string)
	if state.line and state.lineStyle == style then return state.line end

	Line.Destroy(state)

	state.line = AimLineService.new(style)
	state.lineStyle = style
	state.lineOptions = {
		alpha = 1,
		prepare = function()
			state.lineParams = ProjectileService.Params(state.lineShot)
		end,
		cast = function(from: number, to: number)
			return ProjectileService.Cast(state.lineShot, from, to, state.lineParams)
		end,
	}

	return state.line
end

local function alphaOf(state): number
	if state.phase == "Holding" then return 1 end
	if state.phase ~= "Drawing" or not state.clipLength or state.clipLength <= 0 then return 0 end

	return math.clamp((os.clock() - state.phaseStart) / state.clipLength, 0, 1)
end

function Line.Update(controller, state, projectile)
	local style = projectile and projectile.aim_line
	local alpha = if typeof(style) == "string" then alphaOf(state) else 0
	if alpha <= 0 then return Line.Hide(state) end

	local shot = Shot.Build(controller, state, projectile)
	if not shot then return Line.Hide(state) end

	local line = lineFor(state, style)

	state.lineShot = shot
	state.lineOptions.alpha = alpha

	line:Draw(shot.Origin, shot.Direction * shot.Speed, shot.Gravity, ProjectileService.Lifetime(shot), state.lineOptions)
end

function Line.Hide(state)
	if state.line then
		state.line:Hide()
	end
end

function Line.Destroy(state)
	if state.line then
		state.line:Destroy()
	end

	state.line = nil
	state.lineStyle = nil
	state.lineOptions = nil
	state.lineShot = nil
	state.lineParams = nil
end

return Line
