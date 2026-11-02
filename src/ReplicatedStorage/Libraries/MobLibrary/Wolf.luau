return {
	template = "Wolf", --@ ServerStorage.Mobs model it clones
	scale = 0.8, --@ Model:ScaleTo factor applied once to the prototype
	health = 120,

	attack = {
		speed = 1.2,
		damage = 12,
		reach = 14, --@ Studs ahead of its root the bite reaches, and where it stops to bite from
		radius = 5, --@ Studs around that line that get hit
		recovery = 0.12, --@ Short, so the later bite landings keep the combo's rhythm
		animations = { "Bite1", "Bite2", "Bite3", "Bite4" }, --@ Played in order, one per bite

		combo = { --@ Each windup is its clip's visual marker frame / 60 (Moon Animator saves in wolf1.rbxl), so the hit lands with WolfVisuals
			[1] = { windup = 29 / 60 },
			[2] = { windup = 28 / 60 },
			[3] = { windup = 32 / 60 },
			[4] = { --@ Final bite: it backs off, then leaps in and launches the target
				min_range = 18, --@ Studs root to root it backs off to before leaping
				range = 28, --@ Studs root to root it starts the leap from
				back_off = { speed = 42, animation = "DashBack" }, --@ A quick hop back, so the leap follows the third bite without a lull
				windup = 24 / 60, --@ Seconds from the start of the attack to the bite landing
				recovery = 0.8,
				damage = 16,
				radius = 6,
				leap = {
					delay = 0.1, --@ Seconds into the attack it leaves the ground
					speed = 69, --@ Fast enough to cover the same ground in the shorter windup
					lead = 0.25, --@ Seconds of the target's movement it aims ahead
				},
				launch = {
					speed = 45,
					lift = 26,
					ragdoll = 1.3,
				},
			},
		},
	},

	abilities = {
		leap_grab = { --@ Long leap from the edge of the fight; landing on the target grabs and throws it, missing lands it
			min_range = 30, --@ Studs root to root it may leap from, at least
			range = 55, --@ and at most
			users = {
				passive = true, --@ A circling packmate, not the current attacker, may use it
				fresh = 3, --@ Seconds after locking onto a target it may open with it
			},
			ability_cooldown = 15, --@ Seconds before this wolf may use it again
			team_cooldown = 12, --@ Seconds before any packmate may use it on the same player again
			chance = 0.4, --@ Chance it takes the leap each time it is in position
			retry = 2, --@ Seconds before it rolls again after passing on it
			animation = "Leap",
			miss_animation = "LeapLand",
			windup = 0.95, --@ Seconds into the leap clip it lands
			recovery = 1.1,
			radius = 6,
			leap = {
				delay = 0.45, --@ Seconds into the leap clip it leaves the ground
				airtime = 0.5, --@ Seconds it covers the gap in, whatever the distance
				max_speed = 110,
				lead = 0.45, --@ Seconds of the target's movement it aims ahead
				homing = true, --@ Keeps steering at the target while airborne
			},
			cinematic = { --@ PairSceneService scene played on contact
				Name = "WolfGrab",
				AttackerRig = "Any",
				Facing = "Face",
				Spacing = 12, --@ Studs from the held player to the wolf's root
				Duration = 1.0, --@ Seconds the grab holds before the throw starts (the Grab clip is 1.08s)
				IntroFade = 0.05,
				LoopFade = 0.15,
				ReleaseFade = 0.3,
				TimeoutOutcome = "Throw",
				BreakOn = {}, --@ The held player is ragdolled on purpose, so that must not end the scene
				Attacker = { Intro = "Grab" },
				Victim = {
					Status = "IsGrappled",
					Ragdoll = 3.2, --@ Seconds the held player hangs ragdolled: the grab plus the throw up to the release, which carries it on
					Follow = { --@ The held player's root rides this bone of the wolf, turning with it
						Bone = "Bone18", --@ The lower jaw
						Offset = CFrame.new(0, -1.5, -1.5) * CFrame.Angles(0, 0, math.rad(90)), --@ Ahead of and below the jaw, lying crosswise: spine horizontal across the mouth

						--[[ --@ Potential origin of bounciness in the held player's motion while attached to the wolf's jaw
						
						Shake = { --@ Horizontal thrashing on top of the jaw's own motion
							Angle = 25, --@ Most degrees it whips the body around the vertical
							Offset = 1.2, --@ Most studs it jerks the body side to side
							Frequency = 7, --@ How fast it thrashes
						},
						--]] 
					},
				},
				Outcomes = {
					Throw = {
						Attacker = "M1s_Grab n throw",
						Launch = { Victim = true },
						ReleaseAt = { Victim = 1.9 }, --@ Seconds into the throw clip the player is let go
					},
				},
				Throw = {
					Direction = "Left", --@ Relative to the wolf
					Damage = 18,
					Launch = { speed = 50, lift = 28, ragdoll = 1.5 },
				},
			},
		},
		maul = { --@ Pins its target and claws at them: a ragdolled player is mauled where they lie, a standing one is knocked onto their back first
			range = 28, --@ Studs root to root it may pounce on them from
			targets_ragdolled = true,
			chance = 0.2, --@ Chance it mauls a standing target each time it is in position
			ragdolled_chance = 0.75, --@ Chance it mauls a ragdolled one
			retry = 1.5, --@ Seconds before it rolls again after passing on it
			ability_cooldown = 14, --@ Seconds before this wolf may maul again
			team_cooldown = 8, --@ Seconds before any packmate may maul the same player again
			animation = "Leap",
			miss_animation = "LeapLand",
			windup = 0.95, --@ Seconds into the leap clip it lands
			recovery = 0.6,
			radius = 6,
			leap = {
				delay = 0.45, --@ Seconds into the leap clip it leaves the ground
				airtime = 0.5, --@ Seconds it covers the gap in, whatever the distance
				max_speed = 80,
				lead = 0.3, --@ Seconds of the target's movement it aims ahead
				homing = true, --@ Keeps steering at the target while airborne
			},
			cinematic = { --@ PairSceneService scene played on contact
				Name = "WolfMaul",
				AttackerRig = "Any",
				Facing = "Face",
				Spacing = 15, --@ Studs from the victim's root to the wolf's root: its snout is ~11 ahead, so ~4 in front of it
				Duration = "Attacker", --@ Ends when ClawingBitingCombo does
				IntroFade = 0.1,
				LoopFade = 0.15,
				ReleaseFade = 0.3,
				BreakOn = {}, --@ Mauling a ragdolled player must not end the scene
				Attacker = { Intro = "ClawingBitingCombo" },
				Hit = { Marker = "Hit", Damage = 6 }, --@ Damage dealt at each "Hit" marker in ClawingBitingCombo
				Victim = { --@ Placeholder until the victim clips exist on R6: left ragdolled on the ground where they are
					Status = "IsGrappled",
					Anchor = false, --@ Not held in place: the ragdoll lies wherever it falls
					Ragdoll = 4.2, --@ Seconds ragdolled from the pounce through the end of ClawingBitingCombo
				},
				ReleaseRagdoll = { Victim = 2 }, --@ Seconds the victim stays ragdolled afterwards before getting up
			},
		},
	},

	feed = { --@ Eats players' corpses once nothing is left to hunt, tearing limbs off one at a time (CorpseLibrary.Dismember)
		animation = "Eat", --@ Looped; its RemoveLimb marker tears a limb into the jaw and ReleaseLimb lets it go
		range = 70, --@ Studs a corpse is noticed from
		distance = 10, --@ Studs from its root to the corpse's torso it eats from; its snout is ~11 ahead
		feeders = 2, --@ Most wolves eating one corpse at once
		speed = "walk_speed",
		swallow_chance = 0.35, --@ Chance a torn-off limb is swallowed (it disappears) instead of dropped
		duration = 12, --@ Seconds it eats one corpse when Dismember is off and limbs never run out
		carry = { --@ Where a torn-off limb sits in its mouth
			bone = "Bone18", --@ The lower jaw
			offset = CFrame.Angles(0, 0, math.rad(90)),
		},
	},

	visuals = "Combat.Mobs.WolfVisuals", --@ Bite1, Slash2, Slash3, Bite4 in Storage.Particles.CombatVFX.Mobs.Wolf, timed to the clips' markers

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
		Leap = "Leap",
		Eat = "EatingLoop",
		LeapLand = "LeapLand",
	},
}
