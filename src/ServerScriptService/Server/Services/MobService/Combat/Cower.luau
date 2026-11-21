--[[@
	**Cower**: players caught by a mob's cry are stunned and cover up
	- **Who:** every living player within `range` of the mob who isn't held in a pair scene
	- **Stun:** `CombatService:Stun` for `duration` (no moving, no blocking)
	- **Facing:** the effect carries the mob as `Source`; the stunned player turns to face it
	- **Clips:** the `Combat.Cower` client effect plays `start` then loops `loop` on the stunned player's own client until the stun ends; they are Animation names, found anywhere under `Storage.Animations`
]]
local Jloader = require("@game/ReplicatedStorage/JLoader")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Perception = require("../Senses/Perception")

local EFFECT = "Combat.Cower"
local METHOD = "Play"
local HELD = { InPairScene = true }

local Cower = {}

function Cower.Stun(mob, stun: MobTypes.CryStun): { Model }
	local statuses = mob.Services.StatusService
	local combat = Jloader.GetService("CombatService")
	local effects = Jloader.GetService("EffectService")
	local stunned = {}

	for _, character in Perception.PlayersNear(mob.Root.Position, stun.range) do
		if statuses:CheckStatuses(character, HELD) then continue end

		combat:Stun(character, stun.duration)

		effects:SpawnVisual(nil, {
			Effect = EFFECT,
			Method = METHOD,
			Info = {
				Character = character,
				Source = mob.Model,
				Start = stun.start,
				Loop = stun.loop,
				Until = workspace:GetServerTimeNow() + stun.duration,
			},
		})

		table.insert(stunned, character)
	end

	return stunned
end

return Cower
