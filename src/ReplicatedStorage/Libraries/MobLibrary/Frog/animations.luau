--[[@
	**Animations**: key -> Animation name in `Storage.Animations.Mobs.Frog`
	- **Keys** are what the other modules name (`Whip`, `Leap`, `Hurt1`); `Idle`/`Walk`/`Run` drive locomotion
	- **Walks:** `Frog Walk 1` is the long forward cycle; 3 and 4 are mirrored strafes; 2 is the back step
	- **Dashes:** the second authored `Frog Dash Left` mirrored the first, so it was uploaded as `Frog Dash Right`
	- **Victim clips** (`player latched on`, `Tounge Latch On`) live here too; the latch scenes name them directly
]]
return {
	Idle = "Frog Idle",
	Walk = "Frog Walk 1",
	WalkBack = "Frog Walk 2",
	WalkLeft = "Frog Walk 3",
	WalkRight = "Frog Walk 4",
	Run = "Frantic Run",
	DashLeft = "Frog Dash Left",
	DashRight = "Frog Dash Right",
	DashBack = "Frog Back Dash",
	Leap = "Frog Leap",
	Whip = "Frog Whip Attack",
	Tongue = "Frog Tongue Attack",
	Hurt1 = "Frog Flinch 1",
	Hurt2 = "Frog Flinch 2",
	Hurt3 = "Frog Flinch 3",
}
