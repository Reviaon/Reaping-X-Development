return {
	tree = "Hunter", --@ MobService.Trees module that drives it
	scale = 1, --@ Model:ScaleTo factor applied once to the prototype
	health = 100,
	corpse_time = 3, --@ Seconds the body stays after death

	walk_speed = 9, --@ Wander, return and circling speed
	run_speed = 26, --@ Chase speed
	acceleration = 40, --@ Studs per second it gains each second while speeding up
	deceleration = 46, --@ Studs per second it sheds each second while slowing down
	turn_speed = 6, --@ Most radians per second it turns
	turn_responsiveness = 25, --@ How firmly it settles onto its heading once turned

	detect_range = 75, --@ Studs a player is noticed from
	lose_range = 110, --@ Studs past which it gives up on its target, unless a packmate still holds it
	leash_range = 150, --@ Studs from home past which it drops everything and returns
	home_radius = 6, --@ Studs from home that count as being back
	provoke_time = 12, --@ Seconds it stays on whoever hit it, past its detect range and leash
	chase_lead = 0.45, --@ Most seconds of the target's movement it runs ahead of to cut them off

	wander_radius = 28, --@ Studs around home it roams
	wander_pause = { 1.5, 4 }, --@ Seconds it idles between roams
	idle_action_chance = 0.35, --@ Chance an idle_actions animation plays at the start of each idle

	attack_range = nil, --@ Studs root to root before it attacks; nil derives it from the body
	attack = {
		speed = 1, --@ Playback speed of its combo attacks; every combo timing (and leap speed) is scaled by it
		windup = 0.35, --@ Seconds from the start of the attack to the hit
		recovery = 0.25, --@ Seconds after the hit before it can move
		cooldown = 0.1, --@ Seconds between attacks
		damage = 10,
		reach = nil, --@ Studs ahead of its root the attack reaches; nil derives it from the body
		reach_from = 0, --@ Studs ahead of its root the hit volume starts
		radius = 4, --@ Studs around that line that get hit
		step_in = 12, --@ Studs per second it walks into the target during the windup to keep them in reach; 0 holds still
		hitstun = nil, --@ Seconds a hit stuns and locks blocking; nil lasts until its next swing starts, which then holds it through its windup
		hitstun_slack = 0.2, --@ Seconds added to every derived stun to cover the brain's tick; negative leaves a window to escape
		back_off = nil, --@ { speed, animation } for a hit with min_range: how it gets back out to range; nil walks back at pack.retreat_speed
		reaction_weapon = "Melee", --@ WeaponsLibrary entry whose knockback and hit effect an attack borrows
		reaction_combo = 1,
		combo_reset = 2.5, --@ Seconds without an attack before its combo starts over
		combo = {}, --@ Per-hit overrides keyed by combo index: any attack key (hitstun, back_off included), plus range, min_range, animation, hit_animation, miss_animation, marker, leap, launch
	},

	launch_stun = 0.45, --@ Most seconds a player's launch stuns it when it can't ragdoll, before it gets back into the fight

	launch = { --@ Shape filled in for any hit with `launch`: the target is launched (ragdolled if it can be) instead of knocked back
		ragdoll = 1.2, --@ Seconds ragdolled (or stunned, for rigs that can't ragdoll)
		recovery = 0.5, --@ Seconds of hit immunity after getting up
		speed = 40, --@ Horizontal launch speed
		lift = 22, --@ Vertical launch speed
		spin = 360, --@ Degrees per second of tumble
		twist = 0.5,
		flail = 12,
	},

	pounce = { --@ Gap closer from mid range: it stops, faces the target, then bursts at where they are heading; false turns it off
		range = nil, --@ Studs root to root it pounces from; nil derives it from attack_range
		windup = 0.3, --@ Seconds it holds still, facing the target, before bursting
		duration = 0.45, --@ Most seconds the burst lasts
		speed = 58, --@ Burst speed
		lead = 0.35, --@ Seconds of the target's movement it aims ahead
		cooldown = 3.5, --@ Seconds between pounces
		animation = nil, --@ Animation key played as the windup tell
	},

	dash = { --@ Quick hops: dodging swings, slipping around a guard, regrouping after a hit; false turns them all off
		speed = 46, --@ Dash speed
		recovery = 0.12, --@ Seconds after landing before it acts again
		playback = 1.6, --@ Speed the dash clips play at
		animations = { Left = "DashLeft", Right = "DashRight", Back = "DashBack" }, --@ Animation key per direction relative to its facing; a missing one plays none
		dodge = { --@ Hopping out of a player's swing; false turns it off
			chance = 0.3, --@ Chance it reacts to a swing aimed at it
			retry = 0.8, --@ Seconds it ignores swings after passing on one
			cooldown = 4, --@ Seconds before it may dodge again
			range = 15, --@ Studs from the swinging player it reacts within
			arc = 120, --@ Degrees in front of the swinging player that count as aimed at it
			distance = 11, --@ Studs the hop covers
			iframes = 0.3, --@ Seconds it can't be hit from the moment it hops
			escape = 0.3, --@ Chance it breaks a player's combo string, shaking off the stun to hop clear of the next swing; nil never
		},
		flank = { --@ When its target guards against it, hopping around to their side to bite past the guard; false turns it off
			chance = 0.45, --@ Chance each time it is in position
			retry = 1, --@ Seconds before it rolls again after passing
			cooldown = 4, --@ Seconds before it may flank again
			angle = { 110, 150 }, --@ Degrees around the target, from where they face, that it ends up at
			range = nil, --@ Studs root to root it flanks from; nil is twice attack_range
			radius = nil, --@ Studs from the target it backs off to, then circles at; nil is attack_range
			run_chance = 0.4, --@ Chance it backs off and runs wide around instead of strafing around them in a dash
			run_radius = 1.5, --@ How much wider than radius the run goes
			step = 40, --@ Most degrees around the target it aims ahead each tick, which bends the path into a curve
			timeout = 2, --@ Most seconds it spends getting around before attacking from wherever it is
		},
		regroup = true, --@ After a hit stuns it, it hops back out to the ring, or straight back in if it holds the attack turn
	},

	abilities = nil, --@ Named special attacks: an attack spec plus range/min_range, users {passive, fresh}, ability_cooldown, team_cooldown, chance, retry, cinematic, targets_ragdolled (may pick a ragdolled player; otherwise they are skipped) and ragdolled_chance (its chance on one)

	pack = { --@ Teammates share one target, take turns attacking, and the rest circle it
		max_attackers = 1, --@ Teammates allowed to engage the target at once
		bites_per_turn = nil, --@ Attacks an attacker makes before handing off; nil is one full combo, ending on its final hit
		engage_time = 8, --@ Most seconds a turn lasts if it can't finish its attacks
		rest_time = 1.5, --@ Seconds it circles before it may engage again
		retreat_speed = 14, --@ Speed it backs away at, still facing the target
		reposition_chance = 0.4, --@ Chance a teammate leaving its turn sprints to a new spot instead of backing away
		reposition_arc = { 90, 150 }, --@ Degrees around the target, either way, that new spot lies from where it left
		clearance = nil, --@ Studs every other teammate must be from the target before the next engages; nil derives it
		orbit_radius = nil, --@ Studs from the target the circling teammates hold; nil derives it
		orbit_drift = 0.5, --@ Radians ahead of its spot it aims, so the ring keeps turning
		break_in = { --@ When a player keeps hitting a packmate, the nearest circling teammate breaks in to bite them; false turns it off
			after = { 1, 3 }, --@ Hits on packmates in a row before the pack may break in; a { min, max } range rolls a new count each time
			window = 1.5, --@ Most seconds between hits that still count as one streak
			chance = 0.75, --@ Chance the pack breaks in each time a streak gets there
			cooldown = { 2, 5 }, --@ Seconds before the pack breaks in on the same player again (number or { min, max })
			bites = { 1, 3 }, --@ Bites the teammate gets before it goes back to circling (number or { min, max })
		},
	},

	feed = false, --@ Eating corpses when nothing is left to hunt: { animation, range, distance, feeders, speed, swallow_chance, duration, carry = { bone, offset } }; false never feeds

	visuals = nil, --@ Effects module path (under ReplicatedStorage.Modules.Effects) whose Attack plays each combo hit's visual on every client

	animations = {}, --@ Key -> Animation name in Storage.Animations.Mobs.<Mob> (and the template's AnimSaves in Studio)
}
