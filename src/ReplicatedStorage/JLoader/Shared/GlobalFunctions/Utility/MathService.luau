local Math = {}

function Math.Lerp(a, b, t)
	return (a * (1 - t) + b * t)
end

function Math.Clerp(a, b, t)
	local c = (1 - math.cos(t * math.pi)) / 2

	return (a * (1 - c) + b * c)
end

return Math