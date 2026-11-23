--[[@
	**FlyOff**: a passive bird spooked by an attack that missed it flies off, away from the attacker (`startle`)
	- **Climbs** to `startle.altitude` and flies away at `startle.speed` until the spook wears off (`Conditions/Startled`)
	- **Ends any visit** and puts its next one on cooldown, so it doesn't fly straight back to the same player
	- **A hit** that lands turns it to alarm instead (higher in the `Alarm` tree)
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../../Senses/Perception")

local REFRESH = 0.25
local FLAT = Vector3.new(1, 0, 1)

local random = Random.new()

local function settingsOf(mob): MobTypes.Startle
	return mob.Config.startle
end

return {
	Enter = function(mob)
		local startle = settingsOf(mob)
		local greet: MobTypes.Greet? = mob.Config.greet or nil
		local board = mob.Blackboard

		board.Visit = nil
		board.Companion = nil

		if greet then
			board.VisitReadyAt = os.clock() + random:NextNumber(greet.cooldown[1], greet.cooldown[2])
		end

		if mob.Config.flight then
			mob.Altitude = startle.altitude
		end

		mob:Unface()
	end,

	Update = function(mob, data)
		local startle = settingsOf(mob)
		local root = Perception.RootOf(mob.Blackboard.Spooker)
		local now = os.clock()

		if not root then return end
		if data.MovedAt and now - data.MovedAt < REFRESH then return end

		data.MovedAt = now

		local offset = (mob.Root.Position - root.Position) * FLAT
		local away = if offset.Magnitude > 1e-3 then offset.Unit else (mob.Root.CFrame.LookVector * FLAT).Unit

		mob:MoveTo(mob.Root.Position + away * startle.distance, startle.speed)
	end,

	Exit = function(mob)
		mob:Stop()
	end,
}
