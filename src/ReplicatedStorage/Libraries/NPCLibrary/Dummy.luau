return {
    hit_reaction_path = "ReplicatedStorage/Storage/Animations/HitReactions/Universal", --@ These Reactions Will Randomize

    combat = {
        aggressive = false, --@ Fights on spawn; the Aggressive model attribute overrides this live
        weapon = "Melee", --@ WeaponsLibrary entry it swings with; it holds that Tool and wears its rig
        aggro_range = 30, --@ Studs a player is noticed from
        attack_range = nil, --@ Studs it swings from; nil derives it from the next hit's hitbox reach
        attack_interval = 0.6, --@ Seconds it rests after finishing a full combo
        chase = true, --@ Walks toward the target when out of attack_range
    },
}
