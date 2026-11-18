--[[@
	**Tongue latch**: the tongue strike catches a player at range and holds them on it
	- **Strike:** the `Tongue` clip snaps the tongue out at its `Tongue Attack` keyframe (0.783s); a hit there grabs
	- **Hit:** the `FrogTongueLatch` PairScene loops `Frog Tongue LatchOn` (tongue held out ~7 studs) over the victim's `Tounge Latch On`
	  - The two clips were authored as a pair: the tongue's loop tracks the player's neck as both play
	  - The victim struggles (`Default` profile); every tick in `HitTimes` chips `Hit.Damage`
	  - The frog wins: it reels in and latches on (`abilities/latch`'s scene)
	  - The victim escapes, or it's a draw: the frog hops back (`dash.retreat`)
]]
return {
	min_range = 5, --@ Studs root to root
	range = 10,
	chance = 0.3, --@ Per check
	retry = 2,
	ability_cooldown = 14,
	animation = "Tongue",
	windup = 0.783, --@ The clip's `Tongue Attack` keyframe
	recovery = 1.35, --@ The tongue holds out until 2.12s
	reach = 8, --@ Studs ahead of the root the tongue tip lands
	radius = 2,

	cinematic = {
		Name = "FrogTongueLatch",
		AttackerRig = "Any",
		Facing = "Face",
		Spacing = 0, --@ The roots stand together; the victim clip carries the player's body ~7.6 studs out onto the tongue
		LoopWith = "Victim", --@ The frog's 1.92s loop restarts with the victim's 3.42s one, so the tongue never drifts off the neck
		Struggle = "Default",
		IntroFade = 0.1,
		LoopFade = 0.15,
		ReleaseFade = 0.3,
		BreakOn = {},
		Hit = { Damage = 2 }, --@ Per tick
		HitTimes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, --@ Seconds into the hold; the clip carries no hit markers
		Attacker = {
			Loop = "Frog Tongue LatchOn",
			Shift = CFrame.new(-0.25, 0.45, -0.43), --@ Moves the root so the tongue's loop wraps the base of the head, against the torso; tied to the victim's Shift
		},
		Victim = {
			Status = "IsGrappled",
			Loop = "Tounge Latch On",
			Shift = CFrame.new(0, 1.15, 0), --@ The clip drops the kneeling body ~1.2 studs below its root's floor; this lifts it back onto the ground (the frog's Shift rises with it)
		},
		Outcomes = {
			AttackerWins = { Then = "latch" }, --@ Ability whose cinematic follows
			AttackerLoses = { Retreat = true },
			Draw = { Retreat = true },
		},
	},
}
