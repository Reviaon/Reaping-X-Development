return {
	tree = "Hunter", --@ MobService.Trees module
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
	leash_range = 150, --@ Studs from home it returns past
	home_radius = 6, --@ Studs from home that count as home
	provoke_time = 12, --@ Seconds it stays on whoever hit it
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
