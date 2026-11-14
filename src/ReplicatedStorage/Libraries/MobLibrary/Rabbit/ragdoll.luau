--[[@
	**Death ragdoll**: built by `BoneRagdollService` when it dies
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`
	- **Sizes** are template studs; the model's scale (0.6) applies on top
	- **Limbs are one segment each:** the feet end on the `Hand`/`Toe` IK bones, so thigh and foot stay folded as they died
	- **Ears and tail** ride the head and hips
]]
return {
	segments = {
		{ name = "Hips", from = "Hip1", to = "Tail1", across = 1.5, round = true, drives = { "TorsoControl" } },
		{ name = "Chest", parent = "Hips", from = "Spine1", to = "Head", across = 1.3, round = true, drives = { "Spine2" }, cone = 25, twist = 15 },
		{ name = "Head", parent = "Chest", from = "Head", to = "Head.001", across = Vector2.new(1, 1.1), padding = 0.3, drives = { "Head" }, cone = 45, twist = 25 },

		{ name = "ArmR", parent = "Chest", from = "Bicep.R", to = "Hand.R", across = 0.4, padding = 0.2, drives = { "Bicep.R", "Arm.R" }, cone = 50, twist = 10 },
		{ name = "ArmL", parent = "Chest", from = "Bicep.L", to = "Hand.L", across = 0.4, padding = 0.2, drives = { "Bicep.L", "Arm.L" }, cone = 50, twist = 10 },

		{ name = "LegR", parent = "Hips", from = "Thigh.R", to = "Toe.R", across = 0.6, padding = 0.3, drives = { "Thigh.R", "Shin.R" }, cone = 45, twist = 10 },
		{ name = "LegL", parent = "Hips", from = "Thigh.L", to = "Toe.L", across = 0.6, padding = 0.3, drives = { "Thigh.L", "Shin.L" }, cone = 45, twist = 10 },
	},
}
