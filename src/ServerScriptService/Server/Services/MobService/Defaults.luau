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
		windup = 0.35, --@ Seconds from the start of the attack to the hit
		recovery = 0.4, --@ Seconds after the hit before it can move
		cooldown = 0.7, --@ Seconds between attacks
		damage = 10,
		reach = nil, --@ Studs ahead of its root the attack reaches; nil derives it from the body
		reach_from = 0, --@ Studs ahead of its root the hit volume starts
		radius = 4, --@ Studs around that line that get hit
		reaction_weapon = "Melee", --@ WeaponsLibrary entry whose knockback and hit effect an attack borrows
		reaction_combo = 1,
		combo_reset = 2.5, --@ Seconds without an attack before its animation combo starts over
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

	pack = { --@ Teammates share one target, take turns attacking, and the rest circle it
		max_attackers = 1, --@ Teammates allowed to engage the target at once
		bites_per_turn = 3, --@ Attacks an attacker makes before handing off
		engage_time = 5, --@ Most seconds a turn lasts if it can't land its attacks
		rest_time = 1.5, --@ Seconds it circles before it may engage again
		retreat_speed = 14, --@ Speed it backs away at, still facing the target
		reposition_chance = 0.4, --@ Chance a teammate leaving its turn sprints to a new spot instead of backing away
		reposition_arc = { 90, 150 }, --@ Degrees around the target, either way, that new spot lies from where it left
		clearance = nil, --@ Studs every other teammate must be from the target before the next engages; nil derives it
		orbit_radius = nil, --@ Studs from the target the circling teammates hold; nil derives it
		orbit_drift = 0.5, --@ Radians ahead of its spot it aims, so the ring keeps turning
	},

	animations = {}, --@ Key -> Animation name in Storage.Animations.Mobs.<Mob> (and the template's AnimSaves in Studio)
}
