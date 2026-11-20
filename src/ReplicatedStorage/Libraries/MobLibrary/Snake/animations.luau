--[[@
	**Animations**: key -> Animation name in `Storage.Animations.Mobs.Snake`
	- **Ground:** `Idle` (Ground Idle), `Walk` (Slither), `Run` (Fast Slither), `Hurt1-3` (Ground Flinch)
	- **Stance:** the `Engaged` keys, used while coiled (`stance`): `Coil Up Idle` is the hissing stance idle, `Attack Stance N` the stance slither, `S` the reposition back and `E` the reposition right; there is no left reposition clip yet, so a left strafe falls back to the stance slither
	- **Stance in and out:** `Curl` coils up, `Uncoil` drops back to the ground
	- **Victim clips** (`Player ...`) live here too; the scenes name them directly
	- **Unused:** `Player Constrict Bit` (the victim side of the constrict dash before contact)
]]
return {
	Idle = "Snake Idle",
	Walk = "Snake Slither",
	Run = "Slither Fast",
	Hurt1 = "Flinch Idle 1",
	Hurt2 = "Flinch Idle 2",
	Hurt3 = "Flinch Idle 3",

	Curl = "Snake Curl",
	Uncoil = "Snake Uncoil",

	EngagedIdle = "Coil Up Idle",
	EngagedWalk = "Snake Attack Stance N",
	EngagedWalkBack = "Snake Attack Stance S",
	EngagedWalkRight = "Snake Attack Stance E",
	EngagedHurt1 = "Snake Flinch 1",
	EngagedHurt2 = "Snake Flinch 2",
	EngagedHurt3 = "Snake Flinch 3",

	Strike = "Snake Attack",
	Lunge = "Snake Constrict Dash",
}
