return {
	template = "Wolf", --@ ServerStorage.Mobs model it clones
	scale = 0.8, --@ Model:ScaleTo factor applied once to the prototype
	health = 120,
	run_speed = 32, --@ Chase speed; faster than the default

	attack = {
		speed = 1.2,
		damage = 12,
		reach = 14, --@ Studs ahead of its root the bite reaches
		radius = 5, --@ Studs around that line that get hit
		recovery = 0.12, --@ Short, so the late bite landings keep the rhythm
		animations = { "Bite1", "Bite2", "Bite3", "Bite4" }, --@ Played in order, one per bite

		combo = { --@ Windups are each clip's visual frame / 60, so hits land with the visuals
			[1] = { windup = 29 / 60 },
			[2] = { windup = 28 / 60 },
			[3] = { windup = 32 / 60 },
			[4] = { --@ Final bite: backs off, then leaps in and launches
				min_range = 18, --@ Studs root to root it backs off to
				range = 28, --@ Studs root to root it leaps from
				back_off = { speed = 42, animation = "DashBack", visual = "Dash" }, --@ Quick hop back before the leap
				windup = 24 / 60, --@ Seconds until the bite lands
				recovery = 0.8,
				damage = 16,
				radius = 6,
				leap = {
					delay = 0.1, --@ Seconds into the attack it leaves the ground
					speed = 69, --@ Covers the back-off gap within the windup
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
		leap_grab = { --@ Long leap from the fight's edge; a hit grabs and throws, a miss lands
			min_range = 30, --@ Studs root to root it may leap from, at least
			range = 55, --@ and at most
			users = {
				passive = true, --@ A circling packmate may use it
				fresh = 3, --@ Seconds after aggro it may open with it
			},
			ability_cooldown = 15, --@ Seconds before this wolf may use it again
			team_cooldown = 12, --@ Seconds before any packmate may use it on the same player
			chance = 0.4, --@ Chance per check it leaps
			retry = 2, --@ Seconds before it rolls again after passing
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
			cinematic = { --@ PairScene played on contact
				Name = "WolfGrab",
				AttackerRig = "Any",
				Facing = "Face",
				Spacing = 12, --@ Studs from the held player to its root
				Duration = 1.0, --@ Seconds held before the throw (Grab clip is 1.08s)
				IntroFade = 0.05,
				LoopFade = 0.15,
				ReleaseFade = 0.3,
				TimeoutOutcome = "Throw",
				BreakOn = {}, --@ The hold ragdolls the player on purpose
				Attacker = { Intro = "Grab" },
				Victim = {
					Status = "IsGrappled",
					Ragdoll = 3.2, --@ Seconds ragdolled through the release
					Follow = { --@ The held player rides this bone
						Bone = "Bone18", --@ The lower jaw
						Offset = CFrame.new(0, -1.5, -1.5) * CFrame.Angles(0, 0, math.rad(90)), --@ Ahead of and below the jaw, crosswise

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
						ReleaseAt = { Victim = 1.9 }, --@ Seconds into the throw clip it lets go
					},
				},
				Throw = {
					Direction = "Left", --@ Relative to the wolf
					Damage = 18,
					Launch = { speed = 50, lift = 28, ragdoll = 1.5 },
				},
			},
		},
		maul = { --@ Pounce that pins and claws; a ragdolled player is mauled where they lie
			range = 28, --@ Studs root to root it pounces from
			targets_ragdolled = true,
			chance = 0.2, --@ Chance per check on a standing target
			ragdolled_chance = 0.75, --@ Chance per check on a ragdolled one
			visual = "Maul", --@ WolfVisuals timeline played on contact
			retry = 1.5, --@ Seconds before it rolls again after passing
			ability_cooldown = 14, --@ Seconds before this wolf may maul again
			team_cooldown = 8, --@ Seconds before any packmate may maul the same player
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
			cinematic = { --@ PairScene played on contact
				Name = "WolfMaul",
				AttackerRig = "Any",
				Facing = "Face",
				Spacing = 15, --@ Studs from the victim to its root (~4 past its snout)
				Duration = "Attacker", --@ Ends with ClawingBitingCombo
				IntroFade = 0.1,
				LoopFade = 0.15,
				ReleaseFade = 0.3,
				BreakOn = {}, --@ Must not end on the victim's ragdoll
				Attacker = { Intro = "ClawingBitingCombo" },
				Hit = { Damage = 6 }, --@ Damage per hit time
				HitTimes = { 12 / 60, 94 / 60, 137 / 60, 184 / 60 }, --@ Seconds into the combo each hit lands (the visual frames)
				Victim = { --@ Placeholder until R6 victim clips exist: ragdolled where they fall
					Status = "IsGrappled",
					Anchor = false, --@ Not held in place
					Ragdoll = 4.2, --@ Seconds ragdolled through the combo
				},
				ReleaseRagdoll = { Victim = 2 }, --@ Seconds ragdolled after, before getting up
			},
		},
	},

	dash = {
		visual = "Dash", --@ WolfVisuals dust played with every dash
	},

	rally = { --@ Screeches when badly hurt, aggroing nearby wolves, then flees
		health = 0.3, --@ Fraction of max health it screeches at, once per life
		animation = "Screech",
		at = 132 / 60, --@ Seconds into the screech nearby wolves are alerted
		radius = 250, --@ Studs it is heard from
		visual = "Screech", --@ WolfVisuals timeline

		shake = { --@ Shake and FOV for nearby players between these markers
			visual = "ScreechShake",
			from = "Begin",
			to = "End",
		},

		flee = {
			duration = 4, --@ Seconds it runs before heading home
			speed = "run_speed",
			distance = 30, --@ Studs ahead it aims while running
		},
	},

	feed = { --@ Eats corpses once nothing is left to hunt (CorpseLibrary.Dismember)
		animation = "Eat", --@ Looped; RemoveLimb tears a limb into the jaw, ReleaseLimb drops it
		range = 70, --@ Studs a corpse is noticed from
		distance = 10, --@ Studs from its root to the torso it eats from
		feeders = 2, --@ Most wolves on one corpse
		speed = "walk_speed",
		swallow_chance = 0.35, --@ Chance a limb is swallowed instead of dropped
		visual = "Eat", --@ WolfVisuals timeline played every loop
		duration = 12, --@ Seconds it eats when Dismember is off
		carry = { --@ Where a torn-off limb sits in its mouth
			bone = "Bone18", --@ The lower jaw
			offset = CFrame.Angles(0, 0, math.rad(90)),
		},
	},

	visuals = "Combat.Mobs.WolfVisuals", --@ Effects module for its combo, maul, eat, screech and dash visuals

	idle_actions = { "Inspect" }, --@ Animations it may play while idling between roams
	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One plays at random when it takes damage

	rig = {
		root_scale = Vector3.new(0.7, 0.35, 0.5), --@ HumanoidRootPart size as a fraction of the scaled bounds
		hip_ratio = 0.3, --@ HipHeight as a fraction of the scaled height
	},

	animation_exclusive = { --@ Locomotion keys that never blend together
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
