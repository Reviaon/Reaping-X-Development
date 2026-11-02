local Chrono = require("@game/ReplicatedStorage/Libraries/Chrono")

local ChronoConfig = {
	NpcType = "NPC",
	PrimaryPart = "HumanoidRootPart",
	PauseStatuses = { "IsRagdolled", "InPairScene" },
	LiveFolder = "World/Live",
}

Chrono.Config.SetConfig("CHECK_NEW_VERSION", false)
Chrono.Config.SetConfig("PLAYER_REPLICATION", "AUTOMATIC")

Chrono.Config.RegisterEntityType(ChronoConfig.NpcType, {
	BUFFER = 0,
	TICK_RATE = 1 / 20,
	MODEL_REPLICATION_MODE = "NATIVE",
	NORMAL_TICK_DISTANCE = 120,
	HALF_TICK_DISTANCE = 1e6,
	ASSEMBLY_ROOT_PART_CHECK = true,
})

return ChronoConfig
