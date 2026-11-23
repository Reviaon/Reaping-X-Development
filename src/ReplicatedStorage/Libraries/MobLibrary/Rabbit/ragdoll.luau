--[[@
	**Ragdoll**: built by `BoneRagdollService` when it dies, and when a combo finisher or push knocks it down
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **Sizes** are template studs; the model's scale (0.6) applies on top
	- **Limbs bend at the elbow and knee:** the lower halves end on the `Hand`/`Toe` IK bones
	- **Ears** are two pieces each, so they flop; each also drives the `Head.001`/`Head.002` bone beside it, which is the one the ear mesh follows
	- **Tail:** one piece
	- **Knockdown:** it lies limp for the finisher's ragdoll time, then stands back up where it landed
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	knockdown = true, --@ Finishers and pushes ragdoll it too, not just death
	segments = {
		{ name = "Hips", from = "Hip1", to = "Tail1", across = 1.5, round = true, drives = { "TorsoControl" } },
		{ name = "Chest", parent = "Hips", from = "Spine1", to = "Head", across = 1.3, round = true, drives = { "Spine2" }, cone = 40, twist = 25 },
		{ name = "Head", parent = "Chest", from = "Head", to = "Head.001", across = Vector2.new(1, 1.1), padding = 0.3, drives = { "Head" }, cone = 55, twist = 35 },

		{ name = "EarR", parent = "Head", from = "Ear.R", to = "Ear1.R", across = Vector2.new(0.45, 0.15), drives = { "Ear.R", "Head.001.R" }, cone = 60, twist = 25 },
		{ name = "EarTipR", parent = "EarR", from = "Ear1.R", to = "Ear2.R", across = Vector2.new(0.45, 0.15), padding = 0.4, drives = { "Ear1.R", "Head.002.R" }, cone = 60, twist = 25 },
		{ name = "EarL", parent = "Head", from = "Ear.L", to = "Ear1.L", across = Vector2.new(0.45, 0.15), drives = { "Ear.L", "Head.001.L" }, cone = 60, twist = 25 },
		{ name = "EarTipL", parent = "EarL", from = "Ear1.L", to = "Ear2.L", across = Vector2.new(0.45, 0.15), padding = 0.4, drives = { "Ear1.L", "Head.002.L" }, cone = 60, twist = 25 },

		{ name = "ArmR", parent = "Chest", chain = { "Bicep.R", "Arm.R", "Hand.R" }, across = 0.4, padding = 0.2, cone = 70, twist = 20 },
		{ name = "ArmL", parent = "Chest", chain = { "Bicep.L", "Arm.L", "Hand.L" }, across = 0.4, padding = 0.2, cone = 70, twist = 20 },

		{ name = "LegR", parent = "Hips", chain = { "Thigh.R", "Shin.R", "Toe.R" }, across = { 0.6, 0.45 }, padding = 0.3, cone = 65, twist = 20 },
		{ name = "LegL", parent = "Hips", chain = { "Thigh.L", "Shin.L", "Toe.L" }, across = { 0.6, 0.45 }, padding = 0.3, cone = 65, twist = 20 },

		{ name = "Tail", parent = "Hips", from = "Tail1", to = "Tail3", across = 0.5, padding = 0.2, drives = { "Tail1" }, cone = 50, twist = 20 },
	},
}

return ragdoll
