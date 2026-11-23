--[[@
	**Ragdoll**: built by `BoneRagdollService` when it dies, and when a combo finisher or push knocks it down
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **The body** is one link per spine bone, head end first, thinning toward the tail, so it drapes and curls along its whole length; the first link carries `MasterControl`, so the head rides it
	- **The head** hangs off the first link
	- **Knockdown:** it lies limp for the finisher's ragdoll time, then stands back up where it landed
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	knockdown = true, --@ Finishers and pushes ragdoll it too, not just death
	segments = {
		{
			name = "Spine",
			chain = {
				"Bone", "Bone.001", "Bone.002", "Bone.003", "Bone.004", "Bone.005", "Bone.006", "Bone.007", "Bone.008",
				"Bone.009", "Bone.010", "Bone.011", "Bone.012", "Bone.013", "Bone.014", "Bone.015", "Bone.016",
			},
			across = { 1, 0.5 },
			round = true,
			drives = { "MasterControl" },
			cone = 40,
			twist = 20,
		},
		{ name = "Head", parent = "Spine1", from = "Bone.017", to = "Bone.020", across = Vector2.new(0.9, 0.6), padding = 0.2, drives = { "Bone.017" }, cone = 45, twist = 20 },
	},
}

return ragdoll
