--[[@
	**Ragdoll**: built by `BoneRagdollService` when it dies, and when a combo finisher or push knocks it down
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **Sizes** are template studs (authored at scale 1)
	- **Body:** belly, chest, neck and head each bend
	- **Wings** are four flat plates each (`across` = chord, thickness), shoulder to tip, so they fold and trail instead of staying spread
	- **Tail:** four links, then the two long streamers as three links each
	- **Legs** bend twice; the feet are their own pieces, because the `IKTARGET` foot bones hang off the root and would stay behind otherwise
	- **Knockdown:** it lies limp for the finisher's ragdoll time (dropping out of the air if it was flying), then stands back up where it landed
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	knockdown = true, --@ Finishers and pushes ragdoll it too, not just death
	segments = {
		{ name = "Belly", from = "LowerTorso", to = "Torso.001", across = 1.7, padding = 0.3, round = true, drives = { "LowerTorso" } },
		{ name = "Chest", parent = "Belly", from = "Torso.001", to = "Neck", across = 1.8, round = true, drives = { "Torso.001" }, cone = 30, twist = 20 },
		{ name = "Neck", parent = "Chest", from = "Neck", to = "Head", across = 0.8, round = true, drives = { "Neck" }, cone = 50, twist = 30 },
		{ name = "Head", parent = "Neck", from = "Head", to = "UpperBeak", across = 0.9, padding = 0.2, drives = { "Head" }, cone = 50, twist = 30 },

		{ name = "WingR", parent = "Chest", chain = { "Wing.R", "Wing.R.008", "Wing.R.001", "Wing.R.009", "Wing.R.006" }, across = { Vector2.new(1.5, 0.3), Vector2.new(1, 0.2) }, cone = 70, twist = 30 },
		{ name = "WingL", parent = "Chest", chain = { "Wing.L", "Wing.L.008", "Wing.L.001", "Wing.L.009", "Wing.L.006" }, across = { Vector2.new(1.5, 0.3), Vector2.new(1, 0.2) }, cone = 70, twist = 30 },

		{ name = "Tail", parent = "Belly", chain = { "Tail", "Tail.002", "Tail.001", "Tail.003", "Tail.005" }, across = { Vector2.new(1, 0.3), Vector2.new(0.7, 0.2) }, cone = 45, twist = 20 },
		{ name = "StreamerR", parent = "Tail4", chain = { "Tail.R", "Tail.R.001", "Tail.R.002", "Tail.R.003" }, across = Vector2.new(0.4, 0.15), padding = 0.4, cone = 55, twist = 25 },
		{ name = "StreamerL", parent = "Tail4", chain = { "Tail.L", "Tail.L.001", "Tail.L.002", "Tail.L.003" }, across = Vector2.new(0.4, 0.15), padding = 0.4, cone = 55, twist = 25 },

		{ name = "LegR", parent = "Belly", chain = { "Leg.R", "Leg.R.002", "IKTARGET.R" }, across = 0.3, cone = 65, twist = 20 },
		{ name = "FootR", parent = "LegR2", from = "IKTARGET.R", to = "Foot.R.003", across = Vector2.new(0.6, 0.2), padding = 0.2, drives = { "IKTARGET.R" }, cone = 50, twist = 20 },
		{ name = "LegL", parent = "Belly", chain = { "Leg.L", "Leg.L.002", "IKTARGET.L" }, across = 0.3, cone = 65, twist = 20 },
		{ name = "FootL", parent = "LegL2", from = "IKTARGET.L", to = "Foot.L.003", across = Vector2.new(0.6, 0.2), padding = 0.2, drives = { "IKTARGET.L" }, cone = 50, twist = 20 },
	},
}

return ragdoll
