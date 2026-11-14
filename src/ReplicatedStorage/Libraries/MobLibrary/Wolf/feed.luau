--[[@
	**Feed**: eats corpses once nothing is left to hunt
	- **Dismember on** (`CorpseLibrary.Dismember`): each loop's `RemoveLimb` marker tears a limb into the jaw, `ReleaseLimb` drops it, or it's swallowed
	- **Dismember off:** it eats for `duration`, then leaves
]]
return {
	animation = "Eat", --@ Looped
	range = 70, --@ Studs a corpse is noticed from
	distance = 10, --@ Studs from its root to the torso
	feeders = 2, --@ Most wolves per corpse
	speed = "walk_speed",
	swallow_chance = 0.35, --@ Per limb
	visual = "Eat", --@ WolfVisuals timeline per loop
	duration = 12, --@ Seconds, dismember off
	carry = { --@ Where a torn limb sits
		bone = "Bone18", --@ The lower jaw
		offset = CFrame.Angles(0, 0, math.rad(90)),
	},
}
