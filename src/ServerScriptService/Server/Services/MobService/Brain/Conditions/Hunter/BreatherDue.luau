local Tempo = require("../../../Combat/Tempo")

return function(mob, args): boolean
	if not mob:GetTarget() then return false end

	local breather = Tempo.Due(mob)
	if not breather then return false end

	if args.kind then
		return breather.Kind == args.kind
	end

	return true
end
