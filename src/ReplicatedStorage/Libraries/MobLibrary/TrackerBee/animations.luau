--[[@
	**Animations**: key -> Animation name in `Storage.Animations.Mobs.TrackerBee`
	- **Flying:** `Idle` (hover), `Walk` (forward), `Run` (fast flying), `WalkBack`, `WalkLeft`, `WalkRight`
	- **Moves:** `Rage` (spotting prey), `Dash` (stinger dash), `LatchStart` (the fly-in to the latch)
	- **Victim clips** (`Player Bee ...`) live here too; the latch scene names them directly
]]
return {
	Idle = "Bee Idle",
	Walk = "Bee Forward Fly",
	Run = "Bee Fast Flying",
	WalkBack = "Bee Backwards Fly",
	WalkLeft = "Bee Fly Left",
	WalkRight = "Bee Fly Right",

	Rage = "Bee Rage Aggro",
	Dash = "Bee Startup Dash Attack",
	LatchStart = "Bee Startup Latch",
}
