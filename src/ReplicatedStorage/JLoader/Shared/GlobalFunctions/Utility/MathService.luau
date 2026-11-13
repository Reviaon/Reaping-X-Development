local Math = {}

function Math.Lerp(a, b, t)
	return (a * (1 - t) + b * t)
end

function Math.Clerp(a, b, t)
	local c = (1 - math.cos(t * math.pi)) / 2

	return (a * (1 - c) + b * c)
end

function Math.Surge(progress: number, rise: number, ease: number): number
	local at = math.clamp(progress, 0, 1)
	local ramp = math.clamp(rise, 0, 0.95)

	if at < ramp then
		local x = at / ramp
		return x * x * (3 - 2 * x)
	end

	return (1 - (at - ramp) / (1 - ramp)) ^ ease
end

function Math.SurgeShare(rise: number, ease: number): number
	local ramp = math.clamp(rise, 0, 0.95)
	return ramp / 2 + (1 - ramp) / (ease + 1)
end

return Math