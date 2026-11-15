return {
	Library = { "Libraries", "MobLibrary" }, --@ Under ReplicatedStorage; a mob's entry is found by its model name
	Animations = { "Storage", "Animations", "Mobs" }, --@ Under ReplicatedStorage; where each mob's published clips live
	Live = { "World", "Live" }, --@ Under Workspace; where mobs are parented
	ConfigKey = "footsteps", --@ Child module of a MobLibrary entry that turns it on
	Rescan = 0.25, --@ Seconds between looks for stepping mobs in range and their tracks
}
