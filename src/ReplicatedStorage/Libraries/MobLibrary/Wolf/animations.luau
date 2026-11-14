--[[@
	**Animations**: key -> Animation name in `Storage.Animations.Mobs.Wolf`
	- **Keys** are what the other modules name (`Bite1`, `Leap`, `Screech`); `Idle`/`Walk`/`Run` drive locomotion
	- **Studio** falls back to the template's AnimSaves until a clip is uploaded to the group
]]
return {
	Idle = "M1s_Idle",
	Walk = "M1s_Walk",
	WalkLeft = "M1s_WalkL",
	WalkRight = "M1s_WalkR",
	WalkBack = "M1s_WalkB",
	Run = "M1s_Run",
	DashLeft = "M1s_DashL",
	DashRight = "M1s_DashR",
	DashBack = "M1s_DashB",
	Bite1 = "M1s_M1 1",
	Bite2 = "M1s_M1 2",
	Bite3 = "M1s_M1 3",
	Bite4 = "M1s_M1 4",
	Hurt1 = "M1s_React 1",
	Hurt2 = "M1s_React 2",
	Hurt3 = "M1s_React 3",
	Growl = "M1s_Growl",
	Howl = "M1s_Howl complete",
	Screech = "M1s_Screech",
	Inspect = "M1s_Inspect 2",
	GrabThrow = "M1s_Grab n throw",
	Leap = "Leap",
	Eat = "EatingLoop",
	LeapLand = "LeapLand",
}
