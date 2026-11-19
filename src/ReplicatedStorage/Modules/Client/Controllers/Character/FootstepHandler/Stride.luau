local Config = require("./Config")
local Types = require("./Types")

local Stride = {}

function Stride.Foot(leg: BasePart): Types.Foot
	return { Leg = leg, Peak = -math.huge, Armed = true }
end

function Stride.Tip(leg: BasePart): Vector3
	return (leg.CFrame * CFrame.new(0, -leg.Size.Y / 2, 0)).Position
end

function Stride.Reset(foot: Types.Foot)
	foot.Peak = -math.huge
	foot.Armed = true
end

function Stride.Planted(foot: Types.Foot, heading: Vector3): boolean
	local leg = foot.Leg
	local hip = (leg.CFrame * CFrame.new(0, leg.Size.Y / 2, 0)).Position
	local ahead = (Stride.Tip(leg) - hip):Dot(heading)

	if not foot.Armed then
		if ahead <= Config.Rearm then
			foot.Armed = true
			foot.Peak = -math.huge
		end

		return false
	end

	if ahead > foot.Peak then
		foot.Peak = ahead
		return false
	end

	if foot.Peak >= Config.Reach and ahead <= foot.Peak - Config.Drop then
		foot.Armed = false
		return true
	end

	return false
end

return Stride
