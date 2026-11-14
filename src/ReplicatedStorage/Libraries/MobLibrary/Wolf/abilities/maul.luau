--[[@
	**Maul**: a pounce that pins and claws while the victim struggles
	- **Targets:** standing players now and then, ragdolled players far more often
	- **Leap:** the same jump as `abilities/leap_grab`, with less lead
	- **Hit:** the `WolfMaul` PairScene loops the clawing combo until the struggle ends
	  - The wolf wins: it chains into `leap_grab`'s grab and throw
	  - The victim escapes, or it's a draw: the victim gets up and the wolf dashes back (`dash.retreat`)
]]
return {
	range = 28, --@ Studs root to root
	targets_ragdolled = true,
	chance = 0.2, --@ Per check, standing target
	ragdolled_chance = 0.75, --@ Per check, ragdolled target
	visual = "Maul", --@ WolfVisuals timeline on contact
	retry = 1.5, --@ Seconds before rolling again
	ability_cooldown = 14, --@ Seconds, this wolf
	team_cooldown = 8, --@ Seconds, any packmate on the same player
	animation = "Leap",
	miss_animation = "LeapLand",
	windup = 0.95, --@ Seconds into the clip it lands
	recovery = 0.6,
	radius = 6,
	leap = {
		delay = 0.45, --@ Seconds into the clip it leaves the ground
		airtime = 0.5, --@ Seconds, whatever the distance
		max_speed = 80, --@ Same reach as the leap grab
		overrun = 10, --@ Studs eased on past the landing
		settle = 0.3, --@ Least seconds the overrun lasts; faster leaps carry further
		lead = 0.3, --@ Seconds of target movement aimed ahead
		track = 120, --@ Degrees/s it bends while airborne; 0 flies straight
	},
	cinematic = {
		Name = "WolfMaul",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 13, --@ Studs to the victim; their torso sits under the jaw (Bone18 averages 12.8 ahead)
		Struggle = "Default", --@ StruggleLibrary profile; the scene lasts until it ends
		SyncLoops = true, --@ Victim loop starts where the combo is
		IntroFade = 0.1,
		LoopFade = 0.15,
		ReleaseFade = 0.3,
		BreakOn = {}, --@ Must not end on the victim's ragdoll
		Hit = { Damage = 4 }, --@ Per Hit marker in ClawingBitingCombo, every loop
		Attacker = { Loop = "ClawingBitingCombo" },
		Victim = {
			Status = "IsGrappled",
			Intro = "ClawingBitingVictimIntro",
			Loop = "ClawingBitingVictimLoop",
		},
		Outcomes = {
			AttackerWins = { Then = "leap_grab" }, --@ Ability whose cinematic follows
			AttackerLoses = { Retreat = true },
			Draw = { Retreat = true },
		},
	},
}
