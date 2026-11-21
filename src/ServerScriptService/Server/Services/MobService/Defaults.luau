return {
	tree = "Hunter", --@ MobService.Brain.Trees module
	scale = 1, --@ Model:ScaleTo factor
	health = 100,
	corpse_time = 3, --@ Seconds the body stays
	ragdoll = nil, --@ Bone ragdoll built when it dies (BoneRagdollService): { knockdown, segments ={ { name, from, to, parent, across, padding, round, drives, cone, twist, friction } } }; knockdown = true also ragdolls it on finishers and pushes; nil dies without one

	walk_speed = 9, --@ Wander, return and circle speed
	run_speed = 26, --@ Chase speed
	chase_speed = "run_speed", --@ Speed key (or studs/s) Chase runs at
	acceleration = 40,
	deceleration = 46,
	turn_speed = 6, --@ Radians per second
	turn_responsiveness = 25,

	detect_range = 75, --@ Studs it notices players from
	lose_range = 110, --@ Studs it drops its target past
	leash_range = 150, --@ Studs from home a mob with no prey heads back past
	hunt_range = 400, --@ Studs from home a hunt gives up past unless it was just hit; it then retreats without looking until back within leash_range
	return_run = 60, --@ Studs from home past which a returning mob runs instead of walking
	home_radius = 6, --@ Studs from home that count as home
	search = { --@ What it does after losing its prey; false gives up on the spot
		time = 8, --@ Seconds it hunts around the last place it or a packmate saw the prey
		radius = 14, --@ Studs around that place it sniffs through
	},
	
	healing = { --@ Slow healing at home once calm (no prey, not returning or searching); false never heals
		rate = 0.02, --@ Share of max health regained per second
		delay = 10, --@ Seconds after its last hurt before healing starts
		range = nil, --@ Studs from home it heals within; nil is wander_radius
	},

	spawn = { --@ How MobSpawnService zones spawn it; a zone's Cap and Respawn attributes override
		group = { 1, 1 }, --@ How many spawn together, rolled per wave
		respawn = 45, --@ Seconds after the last kill before a cleared zone spawns again
		spread = 16, --@ Studs around the first spawn point the rest of the group lands within
	},
	
	sight = { --@ Line of sight for noticing and keeping targets; false sees through everything
		interval = 0.3, --@ Seconds one look at a target stays fresh
		memory = 6, --@ Seconds it keeps a target it can't see; any packmate's sighting renews it
		hear_range = 18, --@ Studs it senses players within, walls or not
		eye_height = 1.5, --@ Studs above its root it looks from
	},
	sneak = { --@ How a sneaking (crouching) player is sensed; false ignores sneaking
		notice = 5, --@ Studs a sneaker is noticed within, seen or not; further off they only confuse it (the `confuse` mark) until they attack or come this close
		forget = 6, --@ Seconds a noticed sneaker stays noticed by sight and hearing as normal, renewed every time it senses them; after that sneaking hides them again
	},

	threat = { --@ Who it fights once provoked: a decaying ledger per player
		decay = 12, --@ Seconds a player's threat takes to fade to zero
		provoke = 60, --@ Threat for any hostile act (hit, push, tackle, rally call)
		damage = 10, --@ Extra threat per point of damage dealt
		proximity = 30, --@ Most bonus for standing close; fades out at detect_range
		min_dwell = 1.5, --@ Seconds it keeps a new focus before it may switch
		switch_margin = 0.3, --@ A challenger needs this much more threat to take focus
		unreachable = { height = 10, after = 3, scale = 0.25 }, --@ Scales threat of a target it can't path to, or held height above it for after seconds
	},

	path = { --@ Pathfinding for chase, return and stalk; false keeps straight lines only
		min_distance = 12, --@ Closer than this it runs straight without probing
		probe_range = 12, --@ Studs past its nose the lane probe reaches
		probe_scale = 0.6, --@ Lane probe radius as a share of the body radius
		probe_interval = 0.4, --@ Seconds between lane probes while running straight
		stuck_time = 1, --@ Seconds without covering stuck_step that count as stuck
		stuck_step = 2, --@ Studs of travel that reset the stuck timer
		repath = 0.75, --@ Fewest seconds between path requests
		retarget = 10, --@ Studs the goal may drift before the path is replanned
		waypoint_reach = 4, --@ Studs that consume a waypoint (at least body radius + 1.5)
		attempts = 3, --@ Stuck replans in a row without closing in before the target counts as unreachable
		recheck = 4, --@ Seconds before an unreachable target is tested again
		agent_height = 6, --@ Pathfinding agent height
		can_jump = false, --@ Pathfinding agent may jump
	},
	chase_lead = 0.45, --@ Seconds of target movement it cuts ahead of

	wander_radius = 28,
	wander_pause = { 1.5, 4 }, --@ Seconds idle between roams
	idle_action_chance = 0.35, --@ Chance an idle_actions clip plays

	attack_range = nil, --@ Studs root to root; nil derives it
	attack = {
		speed = 1, --@ Scales every combo timing
		windup = 0.35, --@ Seconds to the hit
		recovery = 0.25, --@ Seconds after the hit
		cooldown = 0.1,
		damage = 10,
		reach = nil, --@ Studs ahead of the root; nil derives it
		reach_from = 0, --@ Studs ahead of the root the hit starts
		reach_height = 0, --@ Studs above the root the hit line runs; a short mob raises it to a player's chest
		radius = 4, --@ Studs around the reach line
		step_in = 12, --@ Windup walk-in speed; 0 holds still
		step_in_lead = nil, --@ Seconds before the hit the step-in surges; nil walks in from the start
		step_in_ease = 0, --@ How the surge eases out to a stop at the hit: 0 holds step_in to the hit, 2 slows like (1 - t)^2
		step_in_rise = 0, --@ Share of the surge it spends easing up to step_in (smoothstep); 0 starts at full speed
		hitstun = nil, --@ Seconds; nil lasts until its next windup ends
		hitstun_slack = 0.2, --@ Seconds added to derived stuns
		back_off = nil, --@ { speed, animation, visual } for min_range hits
		reaction_weapon = "Melee", --@ WeaponsLibrary entry for knockback and hit effect
		reaction_combo = 1,
		combo_reset = 2.5, --@ Seconds idle before the combo restarts
		combo = {}, --@ Per-hit overrides by combo index
		grab = nil, --@ Set per combo index: an `abilities` name whose cinematic a hit plays instead of knocking back
		unblockable = false, --@ Lands through a block and a counter
	},

	launch_stun = 0.45, --@ Seconds a launch stuns it when it can't ragdoll

	launch = { --@ Fills any hit with `launch`
		ragdoll = 1.2,
		recovery = 0.5, --@ Seconds of hit immunity after
		speed = 40,
		lift = 22,
		spin = 360,
	},

	pounce = { --@ Mid-range gap closer; false turns it off
		range = nil, --@ nil derives it from attack_range
		windup = 0.3,
		duration = 0.45,
		speed = 58,
		lead = 0.35, --@ Seconds of target movement it aims ahead
		cooldown = 3.5,
		animation = nil, --@ Windup tell
		min_range = nil, --@ Studs closer than which it never pounces; nil is attack_range
		chance = nil, --@ Per check; nil always pounces when ready
		retry = 1, --@ Seconds before rolling again after a failed chance
		arc = nil, --@ { height, hold, resume, home }: a hop clip (`animation`) flown as a real arc from lift-off (`windup`, clip time) for `duration` seconds, landing `stop` studs short of the target, then the clip blends out over `blend` into the chase; nil runs it along the ground at `speed`
		stop = nil, --@ Studs short of the target an arc pounce lands; nil is attack_range
		blend = 0.15, --@ Seconds an arc pounce's clip fades out on landing
		max_speed = nil, --@ Caps the gap an arc pounce covers at this times `duration`
	},

	dash = { --@ Quick hops; false turns them all off
		speed = 46,
		recovery = 0.12,
		playback = 1.6,
		visual = nil, --@ Timeline played with every dash
		animations = { Left = "DashLeft", Right = "DashRight", Back = "DashBack" },
		retreat = 14, --@ Studs it hops back when a held victim escapes (a cinematic outcome with Retreat)
		retreat_pause = 1.5, --@ Seconds after that hop before it attacks or pounces again
		dodge = { --@ Hopping out of a swing
			chance = 0.3,
			retry = 0.8, --@ Seconds it ignores swings after passing
			cooldown = 4,
			range = 15,
			arc = 120, --@ Degrees in front of the swinger
			distance = 11,
			iframes = 0.3,
			escape = 0.3, --@ Chance it breaks a combo string
		},
		flank = { --@ Hopping around a guard
			chance = 0.45,
			retry = 1,
			cooldown = 4,
			angle = { 110, 150 }, --@ Degrees around the target it ends at
			range = nil, --@ nil is twice attack_range
			radius = nil, --@ nil is attack_range
			run_chance = 0.4, --@ Chance it runs wide instead of dashing
			posture = nil, --@ "ground": a mob with a `stance` drops out of it and always runs round facing its path; the Hunter tree shifts it back into the stance after
			run_radius = 1.5,
			step = 40, --@ Degrees it aims ahead per tick
			timeout = 2,
		},

		sidestep = { --@ Hopping off a drawn aim line
			chance = 1, --@ Per draw
			react = { 0.35, 0.8 }, --@ Seconds aimed at before it moves
			cooldown = 4,
			range = 90,
			margin = 2, --@ Studs past its body that count as on the line
			distance = 18, --@ Least studs the hop covers
			interrupts = { "Pounce" }, --@ Locked states it may cut short

			release = { --@ Hopping on a shot's release
				chance = 1, --@ Per release
				dodge = 0.6, --@ Seconds arrows pass through it
			},
		},
		regroup = true, --@ Hops back out after a stun
	},

	circling = nil, --@ The ring Orbit keeps while its target can't be attacked; nil is `pack`, or for a mob without one a ring derived from its reach that it walks round without repositioning

	abilities = nil, --@ Named special attacks; `follow_up = true` marks one only reached through another cinematic's `Then`, `cast_visual` is a timeline played as its clip starts, `posture = "ground" | "stance"` limits it to one side of `stance`, and `faced` (degrees) only lets it fire while the target looks at the mob
	tempo = false, --@ Breaking off between flurries so a lone fighter isn't attack after attack (Combat/Tempo): { flurry = { min, max } attacks, moves = { strafe, back, dash = weight }, strafe = { time, step, speed }, back = { distance, speed }, setup = { ability, chance, margin, speed, hold } or false }; dash reuses the `dash.retreat` hop, and setup backs out past an ability's min_range when the target is too close for it

	pack = { --@ Shared target, turn-taking, circling
		max_attackers = 1,
		bites_per_turn = nil, --@ nil is one full combo
		engage_time = 8, --@ Most seconds per turn
		rest_time = 1.5, --@ Seconds before it may engage again
		retreat_speed = 14,
		reposition_chance = 0.4, --@ Chance it sprints to a new spot instead of backing off
		reposition_arc = { 90, 150 },
		clearance = nil, --@ nil derives it
		orbit_radius = nil, --@ nil derives it
		orbit_drift = 0.5,
		break_in = { --@ A circler bites a player hitting its packmate
			after = { 1, 3 }, --@ Hits in a row
			window = 1.5, --@ Seconds between streak hits
			chance = 0.75,
			cooldown = { 2, 5 },
			bites = { 1, 3 },
		},
	},

	rally = false, --@ Calling for help when badly hurt
	feed = false, --@ Eating corpses when idle
	gnaw = false, --@ Huddling round a long-ragdolled target to chew on it, then scattering when it gets up: { animation, visual, marker, damage, remaining, distance, gnawers, speed, scatter = { distance, spread } }

	evade = false, --@ Prey running from predators (Prey tree): { range, safe, watch, watch_time, distance, speed, refresh, startle, fan, predators }; runs inside range until all are past safe, then watches one inside watch for watch_time; players and whoever hurt it always count
	sleep = false, --@ Prey sleeping at home (Prey tree): { chance, wake_range, wake_speed, resettle, blend, animations = { lie, loop, wake } }
	lurk = false, --@ While its target is held in another pair scene and it isn't (Hunter tree, `States/Lurk`): { band = { min, max } studs from the target's body, nip = { first, every, damage, animation, visual, windup, recovery, reach, speed, approach } }; it keeps to the band and now and then slides in to `reach`, bites (damage at `windup`) and backs out
	alert = false, --@ A clip it plays on getting a fresh target, before anything else (Hunter tree, `States/Alert`): { animation, speed, hold, visual, cooldown }; a new target inside cooldown seconds of the last alert skips it
	swoop = false, --@ The Alarm tree's attack run: { first, every } seconds (rolled) between runs; it lands, walks in at chase_speed and throws one `attack`, then takes off again
	flight = false, --@ Lifting off the ground (`Body/Flight`, the Alarm tree): { altitude, climb, descent, radius, step, speed, land, land_lift, pace }; pace is the studs/s its flight clips play at 1x, so they speed up with it; while lifted the `Engaged<Key>` clips are its flight set
	cry = false, --@ The alarm call (Alarm tree, `States/Cry`): { start, loop, finish, air, call, hold, air_hold, every, radius, kinds, stun = { range, duration, start, loop }, shake }; while it cries the bird carries `IsCrying` and fires the `shake` visuals method; at `call` seconds every mob within radius (of `kinds`, nil for all) turns on its target and players within stun.range are stunned and cower
	stance = false, --@ A combat posture it shifts into on getting a target and out of on losing it (Hunter tree, `States/Stance`): { enter, exit, enter_speed, exit_speed, blend }; while in it `Engaged<Key>` clips replace locomotion and hurt clips

	visuals = nil, --@ Effects module path for combo visuals
	clip_visuals = nil, --@ Animation key -> `visuals` method fired when that clip starts and every time it loops (`Body/Animation:Visual`), at the clip's playback speed; covers locomotion (`Idle`, `Run`, `EngagedIdle`...), idle actions and state clips
	footsteps = false, --@ Camera shake for players near it while a locomotion clip plays (client StepShakeHandler): { gaits = { [animations key] = { at, shake } }, range, min_weight }
	notice = { --@ Shown over its head the moment it notices a player (aggro, or prey startled by one); false shows nothing
		visual = "AttentionVfx", --@ Asset under Storage.Particles.UniversalVFX
		emit = "Notice", --@ The asset's Attachment only this mark plays; other marks' emit attachments are dropped, shared ones always play
		head = "Head", --@ Bone or part it sits on; the root when the rig has neither
		offset = Vector3.new(0, 1.5, 0), --@ Studs above the head the asset's centre sits, scaled with the mob
		cooldown = 8, --@ Fewest seconds between two notices from the same mob
		lifetime = 1.5, --@ Seconds the effect follows the head before it is removed
	},
	confuse = { --@ Shown over its head while it's idle and a player is within range but unnoticed: out of sight and beyond sight.hear_range; false shows nothing
		visual = "AttentionVfx",
		emit = "Confuse",
		range = 40, --@ Studs a hidden player makes it suspicious from
		head = "Head",
		offset = Vector3.new(0, 1.5, 0),
		cooldown = 10, --@ Fewest seconds between two confusions, and after a notice before one
		lifetime = 1.5,
	},

	animations = {}, --@ Key -> Animation name; `Engaged<Key>` (EngagedIdle, EngagedWalk, EngagedHurt1...) replaces that locomotion or hurt clip while engaged: in its `stance` if it has one, else while it has a target
	animation_speeds = {}, --@ Locomotion key -> playback multiplier on top of the speed match (Run = 1.5 plays the run clip 1.5x faster)
}
