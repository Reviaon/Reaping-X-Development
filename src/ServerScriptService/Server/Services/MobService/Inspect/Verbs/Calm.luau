local Verb = { Selects = true }

function Verb.Run(mobs): string
	for _, mob in mobs do
		mob:Calm()
		mob:SetTarget(nil)

		if not mob.Machine:IsLocked() then
			mob.Machine:Exit()
		end
	end

	return `cleared threat on {#mobs} {if #mobs == 1 then "mob" else "mobs"}`
end

return Verb
