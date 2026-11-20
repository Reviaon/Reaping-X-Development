--[[@
	**Crush**: the player drops to the floor in the snake's coils and struggles to get free; failing, they seize
	- **Follow-up only:** reached through `constrict`'s `Then`, never picked on its own
	- **Drop and choke:** `Snake Constrict Fall` into the looped `Snake Constrict Fall Loop` over the victim's `Player Constrict Fall` / `Fall Loop`
	  - Same layout as `constrict`, so the bodies carry on where the squeeze left them
	  - The victim struggles (`Default` profile) while every `HitTimes` tick chokes for `Hit.Damage`
- **The player fails:** the snake unwraps into its hissing coil on top of them, slightly back, then backs away (`LeaveAt`, `Retreat`) while they play `Player Convulsing` once through and go limp
- **The player breaks free, or a draw:** they get up and the snake slithers back
]]
return {
	follow_up = true,
	visual = "Fall", --@ SnakeVisuals: the dust as the body hits the ground (`fall` keyframe, 0.433s)

	cinematic = {
		Name = "SnakeCrush",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 8.7,
		LoopWith = "Victim",
		LoopHold = true, --@ The snake's 3.96s loop holds its last frame until the player's 4.71s loop wraps, instead of restarting 0.75s early
		Struggle = "Default", --@ StruggleLibrary profile; the scene lasts until it ends
		IntroFade = 0.1,
		LoopFade = 0.1,
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 2 }, --@ Per tick
		HitTimes = { 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5 },
		Attacker = {
			Intro = "Snake Constrict Fall",
			Loop = "Snake Constrict Fall Loop",
			Shift = CFrame.new(-0.09, -0.39, -0.01), --@ Jae's hand placement on `Workspace.SnakeExamples.Floor Choke`: the head in the lying player's left shoulder; the coil under them dips into the floor
		},
		Victim = {
			Status = "IsGrappled",
			Intro = "Player Constrict Fall",
			Loop = "Player Constrict Fall Loop",
			Shift = CFrame.new(0, 0, -7.8),
		},
		Outcomes = {
			AttackerWins = {
				Victim = "Player Convulsing", --@ Starts in the lying pose the choke loop ends in
				Attacker = "Coil Up Idle", --@ Lets go into its hissing coil
				Shift = { Attacker = CFrame.new(-3.21, 1.48, -6.29) }, --@ The idle coil sits round its root, the wrap ~7.8 ahead and 3.3 left; this lands it on the player, 1.5 back (measured from the scene's placement above)
				ShiftTime = 0, --@ At once: clients cut straight to the new clip (fades don't replicate), so the root has to jump with it
				EndWith = "Victim", --@ The 12.5s idle doesn't hold the scene past the 4.71s seizure
				LeaveAt = { Attacker = 0.25 }, --@ A beat coiled on the body, then it backs away while the player seizes
				Ragdoll = { Victim = 1.2 }, --@ The player goes limp once the seizure ends
				Retreat = true,
			},
			AttackerLoses = { Retreat = true },
			Draw = { Retreat = true },
		},
	},
}
