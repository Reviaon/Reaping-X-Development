return {
	template = "Wolf", --@ ServerStorage.Mobs model it clones
	scale = 0.8, --@ Model:ScaleTo factor applied once to the prototype
	health = 120,

	attack = {
		damage = 12,
		reach = 14, --@ Studs ahead of its root the bite reaches, and where it stops to bite from
		radius = 5, --@ Studs around that line that get hit
		animations = { "Bite1", "Bite2", "Bite3", "Bite4" }, --@ Played in order, one per bite
	},

	idle_actions = { "Inspect" }, --@ Animations it may play while idling between roams
	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One plays at random when it takes damage

	rig = {
		root_scale = Vector3.new(0.7, 0.35, 0.5), --@ HumanoidRootPart size as a fraction of the scaled bounds
		hip_ratio = 0.3, --@ HipHeight as a fraction of the scaled height
	},

	animation_exclusive = { --@ Locomotion keys whose clips swing the body around when blended, so they never overlap
		{ "WalkLeft", "WalkRight" },
	},

	animations = { --@ Key -> Animation name in Storage.Animations.Mobs.Wolf (and the AnimSaves fallback in Studio)
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
	},
}
