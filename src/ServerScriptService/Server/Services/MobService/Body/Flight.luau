--[[@
	**Flight**: lifts a mob off the ground by raising its Humanoid's `HipHeight`
	- **Altitude:** states set `mob.Altitude` (studs above standing); each frame `Step` eases the lift toward it at `flight.climb` going up, `flight.descent` coming down
	- **Airborne:** lifted past `Settings.Airborne` studs; `Body/Animation` then plays the `Engaged<Key>` clips, so the flight set replaces the ground set
	- **Ragdolled:** while it lies limp the lift drops to standing, so it climbs again from the ground when it gets up rather than snapping back to height
	- **Off** for any mob without a `flight` config
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Rig = require("./Rig")

local Flight = {}

Flight.Settings = {
	Airborne = 0.5,
	Epsilon = 1e-3,
}

local function settingsOf(mob): MobTypes.Flight?
	return mob.Config.flight or nil
end

local function base(mob): number
	return mob.Model:GetAttribute(Rig.Settings.HipHeightAttribute) or 0
end

function Flight.Lift(mob): number
	return mob.Humanoid.HipHeight - base(mob)
end

function Flight.Airborne(mob): boolean
	return settingsOf(mob) ~= nil and Flight.Lift(mob) > Flight.Settings.Airborne
end

function Flight.Step(mob, dt: number)
	local flight = settingsOf(mob)
	if not flight then return end

	if mob.Animation and mob.Animation.Limp then
		mob.Humanoid.HipHeight = base(mob)
		return
	end

	local goal = mob.Altitude or 0
	local lift = Flight.Lift(mob)
	local gap = goal - lift

	if math.abs(gap) <= Flight.Settings.Epsilon then return end

	local rate = if gap > 0 then flight.climb else flight.descent
	local step = math.clamp(gap, -rate * dt, rate * dt)

	mob.Humanoid.HipHeight = base(mob) + lift + step
end

return Flight
