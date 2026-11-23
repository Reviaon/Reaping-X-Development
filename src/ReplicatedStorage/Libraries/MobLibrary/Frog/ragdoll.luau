--[[@
	**Ragdoll**: built by `BoneRagdollService` when it dies, and when a combo finisher or push knocks it down
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **Sizes** are template studs (authored at scale 1)
	- **Body:** `Chest` carries the root `Bone`, so the throat bones and the eyes ride it; `Hips` hangs off it and carries the legs
	- **Limbs bend at every joint:** arms at the elbow and wrist, the long hind legs at the knee, ankle and foot
	- **Knockdown:** it lies limp for the finisher's ragdoll time, then stands back up where it landed
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	knockdown = true, --@ Finishers and pushes ragdoll it too, not just death
	segments = {
		{ name = "Chest", from = "Spine", to = "Head", across = Vector2.new(1.3, 0.8), padding = 0.3, round = true, drives = { "Bone" } },
		{ name = "Hips", parent = "Chest", from = "Hip", to = "Hip2", across = Vector2.new(1.1, 0.7), padding = 0.2, round = true, drives = { "Hip" }, cone = 35, twist = 20 },
		{ name = "Head", parent = "Chest", from = "Head", to = "Tongue1", across = Vector2.new(1, 0.6), padding = 0.3, drives = { "Head" }, cone = 45, twist = 25 },

		{ name = "ArmR", parent = "Chest", chain = { "Bicep.R", "Arm.R", "Palm.R", "Fingers1.R" }, across = { 0.28, 0.2 }, cone = 70, twist = 20 },
		{ name = "ArmL", parent = "Chest", chain = { "Bicep.L", "Arm.L", "Palm.L", "Fingers1.L" }, across = { 0.28, 0.2 }, cone = 70, twist = 20 },

		{ name = "LegR", parent = "Hips", chain = { "Thigh.R", "Shin.R", "Shin2.R", "Foot.R", "Toe6.R" }, across = { 0.4, 0.22 }, cone = 70, twist = 20 },
		{ name = "LegL", parent = "Hips", chain = { "Thigh.L", "Shin.L", "Shin2.L", "Foot.L", "Toe6.L" }, across = { 0.4, 0.22 }, cone = 70, twist = 20 },
	},
}

return ragdoll
