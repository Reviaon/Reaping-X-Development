return {
	template = "Wolf", --@ ServerStorage.Mobs model it clones
	scale = 0.8, --@ Model:ScaleTo factor applied once to the prototype
	health = 120,
	run_speed = 50, --@ Chase speed; faster than the default
	spawn = { group = { 3, 4 } }, --@ A zone spawns a whole pack at once

	attack = {
		speed = 1.2,
		damage = 12,
		reach = 14, --@ Studs ahead of its root the bite reaches
		radius = 5, --@ Studs around that line that get hit
		recovery = 0.12, --@ Short, so the late bite landings keep the rhythm
		step_in = 24, --@ Studs/s its surge peaks at with each bite (~2 studs over the whole surge)
		step_in_lead = 0.3, --@ Seconds before the bite lands it surges, as the bite is thrown
		step_in_rise = 0.35, --@ Share of the surge it eases in over, so it doesn't snap forward
		step_in_ease = 2, --@ Eases the surge out to a stop at the bite
		animations = { "Bite1", "Bite2", "Bite3", "Bite4" }, --@ Played in order, one per bite

		combo = { --@ Windups are each clip's visual frame / 60, so hits land with the visuals
			[1] = { windup = 29 / 60 },
			[2] = { windup = 28 / 60 },
			[3] = { windup = 32 / 60 },
			[4] = { --@ Final bite: a short lunge into the leap grab's grab and throw
				windup = 24 / 60, --@ Seconds until the bite lands
				recovery = 0.8,
				radius = 6,
				leap = {
					delay = 14 / 60, --@ Seconds into the bite it surges, just before the bite is thrown
					speed = 30, --@ A short surge, far less than the leap ability's jump
					overrun = 1.5, --@ Studs it eases on past where the surge lands, so it doesn't stop dead
					lead = 0.2, --@ Seconds of the target's movement it aims ahead
					track = 120, --@ Degrees/s it bends toward the target during the surge
				},
				grab = "leap_grab", --@ A hit plays this ability's grab and throw instead of knocking back
				unblockable = true, --@ Grabs through a block; by the fourth bite the player should be out of the way
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
				overrun = 4, --@ Studs it eases on past the landing, so the leap doesn't stop dead
				lead = 0.45, --@ Seconds of the target's movement it aims ahead
				track = 120, --@ Degrees/s it bends its leap toward the target while airborne; 0 flies straight
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
		maul = { --@ Pounce that pins and claws while the victim struggles; it also goes for ragdolled players
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
				max_speed = 110, --@ Same reach as the leap grab
				overrun = 4, --@ Studs it eases on past the landing, so the leap doesn't stop dead
				lead = 0.3, --@ Seconds of the target's movement it aims ahead
				track = 120, --@ Degrees/s it bends its leap toward the target while airborne; 0 flies straight
			},
			cinematic = { --@ PairScene played on contact; the combo loops while the victim struggles to escape
				Name = "WolfMaul",
				AttackerRig = "Any",
				Facing = "Face",
				Spacing = 13, --@ Studs from the victim to its root: the victim's torso sits under its jaw (Bone18 averages 12.8 ahead through the combo)
				Struggle = "Default", --@ StruggleLibrary profile both sides play; the scene lasts until it ends
				SyncLoops = true, --@ The victim's loop starts where the combo is, so the two stay in step after its intro
				IntroFade = 0.1,
				LoopFade = 0.15,
				ReleaseFade = 0.3,
				BreakOn = {}, --@ Must not end on the victim's ragdoll
				Hit = { Damage = 4 }, --@ Damage per Hit marker in ClawingBitingCombo, every loop
				Attacker = { Loop = "ClawingBitingCombo" },
				Victim = {
					Status = "IsGrappled",
					Intro = "ClawingBitingVictimIntro",
					Loop = "ClawingBitingVictimLoop",
				},
				Outcomes = {
					AttackerWins = { Then = "leap_grab" }, --@ The victim lost: grabbed and thrown by this ability's cinematic
					AttackerLoses = { Retreat = true }, --@ The victim escaped: they get up and the wolf dashes back (dash.retreat)
					Draw = { Retreat = true },
				},
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

	animation_speeds = { --@ Locomotion clip playback multipliers on top of the speed match
		Run = 1.5,
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
