return {
	AggroAt = { Type = "number", Owner = "Mob:SetTarget" },
	Returning = { Type = "boolean", Owner = "Actions/BeginReturn, States/Return, States/Flee" },

	Combo = { Type = "number", Owner = "States/Attack" },
	LastAttackAt = { Type = "number", Owner = "States/Attack, Team/Slots" },
	NextAttackAt = { Type = "number", Owner = "States/Attack" },
	PendingAbility = { Type = "string", Owner = "Conditions/AbilityReady" },
	AbilityReadyAt = { Type = "table", Owner = "Conditions/AbilityReady, States/Attack" },

	FlankReadyAt = { Type = "number", Owner = "Conditions/FlankReady, States/Dash" },
	NextPounceAt = { Type = "number", Owner = "States/Pounce" },
	Staggered = { Type = "boolean", Owner = "States/Disabled, States/Dash" },
	DodgeReadyAt = { Type = "number", Owner = "Dodge" },

	Rallied = { Type = "boolean", Owner = "States/Rally" },
	FleeUntil = { Type = "number", Owner = "States/Rally" },

	Food = { Type = "Instance", Owner = "Conditions/FoodNearby" },
	Chewing = { Type = "Instance", Owner = "States/Feed" },
	Finished = { Type = "table", Owner = "States/Feed" },

	AimWindow = { Type = "table", Owner = "Awareness/Draw" },
	Sidestep = { Type = "table", Owner = "Awareness/Sidestep" },
	SidestepReadyAt = { Type = "number", Owner = "Awareness/Sidestep" },
}
