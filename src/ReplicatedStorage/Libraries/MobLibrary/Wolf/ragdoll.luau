--[[@
	**Death ragdoll**: built by `BoneRagdollService` when it dies
	- **A segment** spans bone `from` to bone `to`, hangs off `parent` at `from`, and places the bones in `drives`; a `chain` is one segment per bone in the list, each hanging off the last
	- **Sizes** are template studs; the model's scale applies on top
	- **Limits:** `cone` and `twist` are degrees from the pose at death
	- **Body:** hips, chest, neck and head; the jaw hangs and the ears flop
	- **Legs** bend at every joint down to the paw
	- **Tail:** one link per tail bone
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local ragdoll: MobTypes.Ragdoll = {
	segments = {
		{ name = "Hips", from = "Spine1", to = "Bone7", across = Vector2.new(2.4, 2.8), round = true, drives = { "TorsoControl" } },
		{ name = "Chest", parent = "Hips", from = "Spine1", to = "Spine3", across = Vector2.new(2.6, 3.2), round = true, drives = { "Spine2" }, cone = 30, twist = 20 },
		{ name = "Neck", parent = "Chest", from = "Spine3", to = "Neck", across = 2, round = true, drives = { "Spine3" }, cone = 35, twist = 25 },
		{ name = "Head", parent = "Neck", from = "Neck", to = "Tongue2", across = Vector2.new(1.6, 1.8), padding = 1.2, drives = { "Neck" }, cone = 45, twist = 30 },
		{ name = "Jaw", parent = "Head", from = "Bone18", to = "Tongue2", across = Vector2.new(1, 0.5), padding = 0.6, drives = { "Bone18" }, cone = 20, twist = 5 },
		{ name = "EarR", parent = "Head", from = "Tail.R", to = "Tail1.R", across = Vector2.new(0.7, 0.2), padding = 0.4, drives = { "Tail.R" }, cone = 45, twist = 20 },
		{ name = "EarL", parent = "Head", from = "Tail.L", to = "Tail1.L", across = Vector2.new(0.7, 0.2), padding = 0.4, drives = { "Tail.L" }, cone = 45, twist = 20 },

		{ name = "ArmR", parent = "Chest", chain = { "Shoulder.R", "Arm.R", "Fot.R", "Fingers3.R" }, across = { 0.9, 0.7 }, cone = 65, twist = 20 },
		{ name = "ArmL", parent = "Chest", chain = { "Shoulder.L", "Arm.L", "Fot.L", "Fingers3.L" }, across = { 0.9, 0.7 }, cone = 65, twist = 20 },

		{ name = "LegR", parent = "Hips", chain = { "Thigh.R", "Shin.R", "Toe.R", "BackToes3.R" }, across = { 1.1, 0.7 }, cone = 65, twist = 20 },
		{ name = "LegL", parent = "Hips", chain = { "Thigh.L", "Shin.L", "Toe.L", "BackToes3.L" }, across = { 1.1, 0.7 }, cone = 65, twist = 20 },

		{ name = "Tail", parent = "Hips", chain = { "Bone7", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8" }, across = { 0.8, 0.5 }, cone = 45, twist = 15 },
	},
}

return ragdoll
