return {
	Dismember = true, --@ Master switch for feeding mobs tearing limbs off corpses; off, they still feed but bodies stay whole

	Tag = "Corpse", --@ CollectionService tag on every dead player's body, and on the copy kept after they respawn
	FolderPath = { "World", "Corpses" }, --@ Workspace folder the copies are kept in
	Lifetime = 120, --@ Seconds a copy stays before it is removed

	RespawnTime = 3, --@ Seconds after death before a player respawns (CorpseService loads characters; auto-loading is off)
	FeastWatch = 15, --@ Most seconds a player keeps watching their own body being eaten before they respawn
	BiteGrace = 3, --@ Seconds after the last limb was torn off that still count as being eaten
	BitAttribute = "CorpseBitAt", --@ Server clock time a limb was last torn off this body
	FeedersAttribute = "CorpseFeeders", --@ How many mobs are eating, or on their way to eat, this body

	HeldTag = "CorpseLimbHeld", --@ On a limb a mob is carrying; every client moves it onto the carrier's bone
	HolderName = "CorpseHolder", --@ ObjectValue under a carried limb pointing at its carrier
	BoneAttribute = "CorpseBone",
	OffsetAttribute = "CorpseOffset",
	TakenAttribute = "CorpseTaken", --@ On a limb that has been torn off

	Limbs = { --@ Torso joint -> limb, everything a body can lose
		Neck = "Head",
		["Left Shoulder"] = "Left Arm",
		["Right Shoulder"] = "Right Arm",
		["Left Hip"] = "Left Leg",
		["Right Hip"] = "Right Leg",
	},
}
