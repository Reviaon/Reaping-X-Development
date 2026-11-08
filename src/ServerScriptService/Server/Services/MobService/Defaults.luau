return {
	tree = "Hunter", --@ MobService.Brain.Trees module
	scale = 1, --@ Model:ScaleTo factor
	health = 100,
	corpse_time = 3, --@ Seconds the body stays

	walk_speed = 9, --@ Wander, return and circle speed
	run_speed = 26, --@ Chase speed
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
		radius = 4, --@ Studs around the reach line
		step_in = 12, --@ Windup walk-in speed; 0 holds still
		hitstun = nil, --@ Seconds; nil lasts until its next windup ends
		hitstun_slack = 0.2, --@ Seconds added to derived stuns
		back_off = nil, --@ { speed, animation, visual } for min_range hits
		reaction_weapon = "Melee", --@ WeaponsLibrary entry for knockback and hit effect
		reaction_combo = 1,
		combo_reset = 2.5, --@ Seconds idle before the combo restarts
		combo = {}, --@ Per-hit overrides by combo index
	},

	launch_stun = 0.45, --@ Seconds a launch stuns it when it can't ragdoll

	launch = { --@ Fills any hit with `launch`
		ragdoll = 1.2,
		recovery = 0.5, --@ Seconds of hit immunity after
		speed = 40,
		lift = 22,
		spin = 360,
		twist = 0.5,
		flail = 12,
	},

	pounce = { --@ Mid-range gap closer; false turns it off
		range = nil, --@ nil derives it from attack_range
		windup = 0.3,
		duration = 0.45,
		speed = 58,
		lead = 0.35, --@ Seconds of target movement it aims ahead
		cooldown = 3.5,
		animation = nil, --@ Windup tell
	},

	dash = { --@ Quick hops; false turns them all off
		speed = 46,
		recovery = 0.12,
		playback = 1.6,
		visual = nil, --@ Timeline played with every dash
		animations = { Left = "DashLeft", Right = "DashRight", Back = "DashBack" },
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

	abilities = nil, --@ Named special attacks

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

	visuals = nil, --@ Effects module path for combo visuals

	animations = {}, --@ Key -> Animation name
}
