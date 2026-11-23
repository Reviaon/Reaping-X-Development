--[[@
	**Death ragdoll**: built by `BoneRagdollService` when it dies, so it drops out of its hover instead of hanging there
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **Sizes** are template studs; the model's scale (1.83) applies on top
	- **Body:** thorax, head, and the abdomen as two links down to the stinger
	- **Wings** hinge once, at the bone that beats them (`.001`); each is a flat plate
	- **Limbs:** all six bend twice along their length; the antennae are three links each
	- **Death only:** it is too big to be knocked down
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	segments = {
		{ name = "Thorax", from = "Torso", to = "Neck", across = 1, round = true, drives = { "Torso" } },
		{ name = "Head", parent = "Thorax", from = "Neck", to = "Antler.L", across = 0.9, drives = { "Neck" }, cone = 45, twist = 30 },
		{ name = "Abdomen", parent = "Thorax", chain = { "Stinger", "Stinger.001", "Stinger.003" }, across = { 1.1, 0.7 }, padding = 0.4, round = true, cone = 40, twist = 20 },

		{ name = "UpperWingR", parent = "Thorax", from = "UpperWing.R.001", to = "UpperWing.R.002", across = Vector2.new(0.9, 0.08), padding = 0.4, drives = { "UpperWing.R.001" }, cone = 70, twist = 35 },
		{ name = "UpperWingL", parent = "Thorax", from = "UpperWing.L.001", to = "UpperWing.L.002", across = Vector2.new(0.9, 0.08), padding = 0.4, drives = { "UpperWing.L.001" }, cone = 70, twist = 35 },
		{ name = "MiddleWingR", parent = "Thorax", from = "MiddleWing.R.001", to = "MiddleWing.R.002", across = Vector2.new(0.7, 0.08), padding = 0.4, drives = { "MiddleWing.R.001" }, cone = 70, twist = 35 },
		{ name = "MiddleWingL", parent = "Thorax", from = "MiddleWing.L.001", to = "MiddleWing.L.002", across = Vector2.new(0.7, 0.08), padding = 0.4, drives = { "MiddleWing.L.001" }, cone = 70, twist = 35 },
		{ name = "LowerWingR", parent = "Thorax", from = "LowerWing.R.001", to = "LowerWing.R.002", across = Vector2.new(0.5, 0.08), padding = 0.6, drives = { "LowerWing.R.001" }, cone = 70, twist = 35 },
		{ name = "LowerWingL", parent = "Thorax", from = "LowerWing.L.001", to = "LowerWing.L.002", across = Vector2.new(0.5, 0.08), padding = 0.6, drives = { "LowerWing.L.001" }, cone = 70, twist = 35 },

		{ name = "AntennaR", parent = "Head", chain = { "Antler.R", "Antler.R.003", "Antler.R.006", "Antler.R.010" }, across = 0.15, cone = 55, twist = 25 },
		{ name = "AntennaL", parent = "Head", chain = { "Antler.L", "Antler.L.003", "Antler.L.006", "Antler.L.010" }, across = 0.15, cone = 55, twist = 25 },

		{ name = "UpperArmR", parent = "Thorax", chain = { "UpperArm.R", "UpperArm.R.001", "UpperArm.R.002", "UpperArm.R.003" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
		{ name = "UpperArmL", parent = "Thorax", chain = { "UpperArm.L", "UpperArm.L.001", "UpperArm.L.002", "UpperArm.L.003" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
		{ name = "MiddleArmR", parent = "Thorax", chain = { "MiddleArm.R", "MiddleArm.R.003", "MiddleArm.R.004", "MiddleArm.R.006" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
		{ name = "MiddleArmL", parent = "Thorax", chain = { "MiddleArm.L", "MiddleArm.L.003", "MiddleArm.L.004", "MiddleArm.L.006" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
		{ name = "LegR", parent = "Thorax", chain = { "Middle.R", "Middle.R.001", "Middle.R.003", "Middle.R.004" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
		{ name = "LegL", parent = "Thorax", chain = { "Middle.L", "Middle.L.001", "Middle.L.003", "Middle.L.004" }, across = { 0.3, 0.2 }, cone = 65, twist = 20 },
	},
}

return ragdoll
