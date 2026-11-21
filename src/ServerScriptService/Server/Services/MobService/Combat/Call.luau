--[[@
	**Call**: a mob's call that turns other mobs onto its target
	- **Provoke:** every living mob within `radius` of the caller, other than the caller, is provoked onto `target`
	  - `kinds` limits it to mobs with those names; nil calls every kind (the mockingjay's alarm), `{ mob.Name }` only its own (the wolf's rally)
]]
local Jloader = require("@game/ReplicatedStorage/JLoader")

local Call = {}

function Call.Provoke(mob, target: Model, radius: number, kinds: { string }?): number
	local called = 0

	for other in Jloader.GetService("MobService"):GetMobs() do
		if other == mob or other.Dead or not other.Root then continue end
		if kinds and not table.find(kinds, other.Name) then continue end

		if (other.Root.Position - mob.Root.Position).Magnitude <= radius then
			other:Provoke(target)
			called += 1
		end
	end

	return called
end

return Call
