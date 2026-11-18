--[[@
	**Latch**: the frog leaps onto a player's face and clings on until they wrench it off
	- **Leap:** `Leap` leaves the ground at its `Leap` keyframe (0.067s); the clip hops on the spot, so the root flies a real arc (`leap.arc`)
	  - The clip plays to its airborne pose, then stretches the rest of its hop over the flight so contact (0.9s) lands on arrival
	  - The arc ends on the face, where `FrogLatch` seats the frog, so the latch picks the body up where the leap left it
	- **Hit:** the `FrogLatch` PairScene loops `Frog LatchOn` (which lifts the frog to head height) over the victim's `player latched on`
	  - The two clips were authored as a pair: the frog's own clip tracks the struggling head, so it is placed once and never follows a bone
	  - The victim struggles (`Default` profile); every tick in `HitTimes` chips `Hit.Damage` until it ends
	  - Whoever wins, the frog hops back off (`dash.retreat`)
	- **Shared:** `abilities/tongue_latch` chains into this scene when its own struggle is won
]]
return {
	min_range = 9, --@ Studs root to root; closer than this it backs out first (`tempo.setup`)
	range = 22,
	chance = 0.35, --@ Per check
	retry = 2, --@ Seconds before rolling again
	ability_cooldown = 12, --@ Seconds, this frog
	animation = "Leap",
	windup = 0.75, --@ Latest it expects contact: lift-off plus the flight; the hit itself waits for `arc.contact`, falling back to 0.5s past this
	recovery = 0.6,
	reach = 1.5, --@ Studs of the hit line ahead of the root
	reach_height = 0, --@ The arc ends at the player's chest, so the hit line runs level with the root
	radius = 3,

	leap = {
		delay = 0.067, --@ The clip's `Leap` keyframe: the arc starts here
		airtime = 0.55, --@ Seconds in the air, whatever the distance
		max_speed = 50, --@ Caps the gap one leap covers at 27.5 studs
		lead = 0.3, --@ Seconds of target movement aimed ahead
		arc = {
			height = 3.5, --@ Studs the root rises above the straight line to the face at the peak, on top of the clip's own hop
			hold = 0.15, --@ Clip time of the airborne pose: from here the clip is re-timed to arrive with the root
			resume = 0.9, --@ Clip time it reaches on arrival
			contact = 0.9, --@ Clip time the hit lands
			seat = Vector3.new(-0.03, 2.66, -0.16), --@ Studs from `FrogLatch`'s seat to where the arc ends: the body's offset between this clip at contact and `Frog LatchOn`'s first frame
			home = 14, --@ Studs/s the landing slides after a moving target
		},
	},

	cinematic = {
		Name = "FrogLatch",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 0, --@ The roots stand together; the clip lifts the frog onto the face
		Struggle = "Default", --@ StruggleLibrary profile; the scene lasts until it ends
		IntroFade = 0.1,
		LoopFade = 0, --@ The leap arrives with the body where this loop's first frame has it, so it cuts in; a fade blends through a low pose
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 3 }, --@ Per tick
		HitTimes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, --@ Seconds into the hold; the clip carries no hit markers
		Attacker = {
			Loop = "Frog LatchOn",
			Shift = CFrame.new(0, -0.55, -0.15), --@ Sinks the root below standing and in toward the player, so the clip's palms grip the face surface all the way through the loop
		},
		Victim = {
			Status = "IsGrappled",
			Loop = "player latched on",
		},
		Outcomes = {
			AttackerWins = { Retreat = true },
			AttackerLoses = { Retreat = true },
			Draw = { Retreat = true },
		},
	},
}
