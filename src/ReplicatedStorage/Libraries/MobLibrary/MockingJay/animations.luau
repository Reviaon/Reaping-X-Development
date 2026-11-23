--[[@
	**Animations**: key -> Animation name in `Storage.Animations.Mobs.MockingJay`
	- **Ground:** `Idle`, `Walk`, `Run`, `Peck` (eating, an idle action)
	- **Flight:** the `Engaged` keys, used while it is lifted off the ground (`Body/Flight`): `Fly Idle` hovers, `Fly Forward` circles, `Fly Fast` hurries
	- **Greeting:** `Startup` then the held `Bow`, when it walks up to a player it visits
	- **Cry:** `CryStart`, `CryLoop`, `CryEnd` on the ground; `FlyCry`, `FlyCryEnd` in the air
	- **Land:** `Land`, from the hover to the ground
	- **Player clips** (`Player Jay ...`) live here too; `greet.answer` names them directly
]]
return {
	Idle = "Jay Ground Idle",
	Walk = "Jay Ground Walk",
	Run = "Jay Ground Run",
	Peck = "Jay Ground Peck",

	EngagedIdle = "Jay Fly Idle",
	EngagedWalk = "Jay Fly Forward",
	EngagedRun = "Jay Fly Fast",
	EngagedWalkBack = "Jay Fly Backwards",
	EngagedWalkLeft = "Jay Fly Left",
	EngagedWalkRight = "Jay Fly Right",

	Startup = "Jay Startup",
	Bow = "Jay Bow",

	CryStart = "Jay Cry Start",
	CryLoop = "Jay Cry Loop",
	CryEnd = "Jay Cry End",
	FlyCry = "Jay Fly Cry Loop",
	FlyCryEnd = "Jay Fly Cry End",
	Land = "Jay Land",
}
