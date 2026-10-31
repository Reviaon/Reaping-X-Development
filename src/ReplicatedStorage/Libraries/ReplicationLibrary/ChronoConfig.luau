local Chrono = require("@game/ReplicatedStorage/Libraries/Chrono")

local ChronoConfig = {
	NpcType = "NPC",
	PrimaryPart = "HumanoidRootPart",
	PauseStatus = "IsRagdolled",
	LiveFolder = "World/Live",
}

Chrono.Config.SetConfig("CHECK_NEW_VERSION", false)
Chrono.Config.SetConfig("PLAYER_REPLICATION", "AUTOMATIC")

Chrono.Config.RegisterEntityType(ChronoConfig.NpcType, {
	BUFFER = 0,
	TICK_RATE = 1 / 20,
	MODEL_REPLICATION_MODE = "NATIVE",
	HALF_TICK_DISTANCE = math.huge,
	ASSEMBLY_ROOT_PART_CHECK = true,
})

return ChronoConfig
