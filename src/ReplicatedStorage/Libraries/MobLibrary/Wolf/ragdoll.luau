--[[@
	**Death ragdoll**: built by `BoneRagdollService` when it dies
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`
	- **Sizes** are template studs; the model's scale applies on top
	- **Limits:** `cone` and `twist` are degrees from the pose at death
]]
return {
	segments = {
		{ name = "Hips", from = "Spine1", to = "Bone7", across = Vector2.new(2.4, 2.8), round = true, drives = { "TorsoControl" } },
		{ name = "Chest", parent = "Hips", from = "Spine1", to = "Spine3", across = Vector2.new(2.6, 3.2), round = true, drives = { "Spine2" }, cone = 20, twist = 15 },
		{ name = "Head", parent = "Chest", from = "Neck", to = "Tongue2", across = Vector2.new(1.6, 1.8), padding = 1.2, drives = { "Neck" }, cone = 40, twist = 25 },

		{ name = "ArmR", parent = "Chest", from = "Shoulder.R", to = "Arm.R", across = 0.9, drives = { "Shoulder.R" }, cone = 50, twist = 15 },
		{ name = "PawR", parent = "ArmR", from = "Arm.R", to = "Fot.R", across = 0.7, padding = 0.6, drives = { "Arm.R" }, cone = 50, twist = 5 },
		{ name = "ArmL", parent = "Chest", from = "Shoulder.L", to = "Arm.L", across = 0.9, drives = { "Shoulder.L" }, cone = 50, twist = 15 },
		{ name = "PawL", parent = "ArmL", from = "Arm.L", to = "Fot.L", across = 0.7, padding = 0.6, drives = { "Arm.L" }, cone = 50, twist = 5 },

		{ name = "ThighR", parent = "Hips", from = "Thigh.R", to = "Shin.R", across = 1.1, drives = { "Thigh.R" }, cone = 50, twist = 15 },
		{ name = "ShinR", parent = "ThighR", from = "Shin.R", to = "Toe.R", across = 0.7, padding = 0.8, drives = { "Shin.R", "Toe.R" }, cone = 50, twist = 5 },
		{ name = "ThighL", parent = "Hips", from = "Thigh.L", to = "Shin.L", across = 1.1, drives = { "Thigh.L" }, cone = 50, twist = 15 },
		{ name = "ShinL", parent = "ThighL", from = "Shin.L", to = "Toe.L", across = 0.7, padding = 0.8, drives = { "Shin.L", "Toe.L" }, cone = 50, twist = 5 },

		{ name = "TailBase", parent = "Hips", from = "Bone7", to = "Tail4", across = 0.8, drives = { "Bone7" }, cone = 35, twist = 10 },
		{ name = "TailTip", parent = "TailBase", from = "Tail4", to = "Tail8", across = 0.6, drives = { "Tail4" }, cone = 35, twist = 10 },
	},
}
