return {
	AggroAt = { Type = "number", Owner = "Mob:SetTarget" },
	NoticedAt = { Type = "number", Owner = "Senses/Notice" },
	Returning = { Type = "boolean", Owner = "Actions/BeginReturn, Actions/AcquireTarget, States/Return, States/Flee" },
	Retreating = { Type = "boolean", Owner = "Actions/BeginReturn, States/Return, States/Flee, Mob:Provoke" },
	Search = { Type = "table", Owner = "Actions/AcquireTarget, States/Search" },

	Combo = { Type = "number", Owner = "States/Attack" },
	LastAttackAt = { Type = "number", Owner = "States/Attack, Team/Slots" },
	NextAttackAt = { Type = "number", Owner = "States/Attack, States/Dash" },
	PendingAbility = { Type = "string", Owner = "Conditions/AbilityReady" },
	AbilityReadyAt = { Type = "table", Owner = "Conditions/AbilityReady, States/Attack" },

	FlankReadyAt = { Type = "number", Owner = "Conditions/FlankReady, States/Dash" },
	NextPounceAt = { Type = "number", Owner = "States/Pounce, States/Dash" },
	Staggered = { Type = "boolean", Owner = "States/Disabled, States/Dash" },
	DodgeReadyAt = { Type = "number", Owner = "Combat/Dodge" },

	Rallied = { Type = "boolean", Owner = "States/Rally, Body/Healing" },
	FleeUntil = { Type = "number", Owner = "States/Rally" },

	Food = { Type = "Instance", Owner = "Conditions/FoodNearby" },
	Chewing = { Type = "Instance", Owner = "States/Feed" },
	Finished = { Type = "table", Owner = "States/Feed" },

	Predators = { Type = "table", Owner = "Conditions/PredatorNear, Conditions/Disturbed" },
	EvadedAt = { Type = "number", Owner = "States/Evade, States/Watch" },
	WatchUntil = { Type = "number", Owner = "Conditions/Wary, States/Evade" },
	StartledUntil = { Type = "number", Owner = "States/Wake" },
	Asleep = { Type = "boolean", Owner = "Conditions/Asleep, States/Sleep, States/Wake" },
	Sleeper = { Type = "boolean", Owner = "Conditions/Asleep" },

	AimWindow = { Type = "table", Owner = "Senses/Awareness/Draw" },
	Sidestep = { Type = "table", Owner = "Senses/Awareness/Sidestep" },
	SidestepReadyAt = { Type = "number", Owner = "Senses/Awareness/Sidestep" },
}
