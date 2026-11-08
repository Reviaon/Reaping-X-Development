local Types = require("./Types")

local Hurt = {}

local random = Random.new()

function Hurt.Start(session: Types.Session)
	local humanoid = session.Humanoid
	local last = humanoid.Health

	session.Trove:Connect(humanoid.HealthChanged, function(health: number)
		local reactions = session.Profile.hurt

		if health < last and health > 0 and not session.State.Attacking and #reactions > 0 then
			session.Animator:Play(reactions[random:NextInteger(1, #reactions)])
		end

		last = health
	end)
end

return Hurt
