local Jloader = require("@game/ReplicatedStorage/JLoader")
local Attacks = require("../../Combat/Attacks")

local FALLBACK_LENGTH = 3
local SCREECHING = "IsScreeching"

local function call(mob, rally)
	local target = mob:GetTarget()
	if not target then return end

	for other in Jloader.GetService("MobService"):GetMobs() do
		if other == mob or other.Dead or other.Name ~= mob.Name or not other.Root then continue end

		if (other.Root.Position - mob.Root.Position).Magnitude <= rally.radius then
			other:Provoke(target)
		end
	end
end

return {
	Armored = true,

	Enter = function(mob, data)
		local rally = mob.Config.rally

		data.Rally = rally
		data.Track = mob.Animation:PlayAction(rally.animation)

		mob:Stop()
		mob:Unface()

		if mob.Team then
			mob.Team:ReleaseSlot(mob)
		end

		Attacks.Shot(mob, rally.visual)

		local shake = rally.shake

		if data.Track and shake then
			data.Markers = {
				data.Track:GetMarkerReachedSignal(shake.from):Connect(function()
					mob.Model:SetAttribute(SCREECHING, true)
					Attacks.Shot(mob, shake.visual)
				end),
				data.Track:GetMarkerReachedSignal(shake.to):Connect(function()
					mob.Model:SetAttribute(SCREECHING, nil)
				end),
			}
		end
	end,

	Update = function(mob, data, _, elapsed)
		local rally = data.Rally

		if mob.Services.KnockbackService.Active(mob.Model) then
			Jloader.GetService("CombatService"):CancelKnockback(mob.Model)
		end

		if not data.Called and elapsed >= rally.at then
			data.Called = true
			mob.Blackboard.Rallied = true
			call(mob, rally)
		end

		local length = if data.Track and data.Track.Length > 0 then data.Track.Length else FALLBACK_LENGTH

		if elapsed >= length and not data.Done then
			data.Done = true

			if data.Called then
				mob.Blackboard.FleeUntil = os.clock() + rally.flee.duration
			end
		end
	end,

	Locked = function(_, data)
		return not data.Done
	end,

	Done = function(_, data)
		return data.Done == true
	end,

	Exit = function(mob, data)
		local rally = data.Rally

		for _, connection in data.Markers or {} do
			connection:Disconnect()
		end

		mob.Model:SetAttribute(SCREECHING, nil)

		if data.Done then return end

		mob.Animation:Stop(rally.animation)

		if data.Called then
			mob.Blackboard.FleeUntil = os.clock() + rally.flee.duration
		end
	end,
}
