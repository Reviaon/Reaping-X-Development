--[[@
	**Gesture**: a player answers a mob with a gesture of their own
	- **Who:** the one player handed in; refused while they are stunned, ragdolled or held in a pair scene
	- **Placement:** with `spacing` the player is stood that many studs from the mob's root, on the line between the two as it was when they answered, looking straight down it; `side` shifts them to their right
	  - The clips are authored against the mob's own pose (a hand onto a bowed head), so the two have to meet at a set distance
	  - `Play` returns the point on that line the mob should face, so the two end up square to each other
	- **Clips:** the `Combat.Gesture` client effect plays `start` then loops `loop` on that player's own client for `duration` seconds; they are Animation names, found anywhere under `Storage.Animations`
	- **Free to go:** nothing holds the player; walking off ends it early
]]
local Jloader = require("@game/ReplicatedStorage/JLoader")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../Senses/Perception")

local EFFECT = "Combat.Gesture"
local METHOD = "Play"
local BUSY = { IsStunned = true, IsRagdolled = true, InPairScene = true }
local FLAT = Vector3.new(1, 0, 1)

local Gesture = {}

local function spot(mob, from: Vector3, gesture: MobTypes.Gesture): (Vector3, Vector3?, Vector3?)
	local spacing = gesture.spacing
	if not spacing then return from, nil, nil end

	local centre = mob.Root.Position
	local offset = (centre - from) * FLAT
	local toward = if offset.Magnitude > 1e-3 then offset.Unit else -(mob.Root.CFrame.LookVector * FLAT).Unit
	local line = centre - toward * spacing
	local right = toward:Cross(Vector3.yAxis)

	return line, line + right * (gesture.side or 0), toward
end

function Gesture.Play(mob, character: Model, gesture: MobTypes.Gesture): Vector3?
	local root = Perception.RootOf(character)
	if not root or mob.Services.StatusService:CheckStatuses(character, BUSY) then return nil end

	local facing, stand, look = spot(mob, root.Position, gesture)

	Jloader.GetService("EffectService"):SpawnVisual(nil, {
		Effect = EFFECT,
		Method = METHOD,
		Info = {
			Character = character,
			Source = mob.Model,
			Stand = stand,
			Look = look,
			Start = gesture.start,
			Loop = gesture.loop,
			Until = workspace:GetServerTimeNow() + gesture.duration,
		},
	})

	return facing
end

return Gesture
