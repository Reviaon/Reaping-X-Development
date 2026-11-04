return function(B)
	return B.Selector({
		B.Sequence({
			B.Condition("IsDisabled"),
			B.State("Disabled", { force = true }),
		}),

		B.Sequence({
			B.Condition("Fleeing"),
			B.State("Flee"),
		}),

		B.Sequence({
			B.Condition("IsReturning"),
			B.State("Return"),
		}),

		B.Sequence({
			B.Action("AcquireTarget"),
			B.Selector({
				B.Sequence({
					B.Condition("BeyondLeash"),
					B.Action("BeginReturn"),
					B.State("Return"),
				}),
				B.Sequence({
					B.Condition("RallyReady"),
					B.State("Rally"),
				}),
				B.Sequence({
					B.Condition("ProjectileIncoming"),
					B.State("Dash", { args = { kind = "sidestep" }, force = true }),
				}),
				B.Sequence({
					B.Condition("Regrouping"),
					B.State("Dash", { args = { kind = "regroup" } }),
				}),
				B.Sequence({
					B.Condition("AbilityReady"),
					B.Condition("AttackReady"),
					B.State("Attack", { args = { ability = true } }),
				}),
				B.Sequence({
					B.Action("ClaimAttackSlot"),
					B.Condition("TargetOpen"),
					B.Selector({
						B.Sequence({
							B.Condition("FlankReady"),
							B.State("Dash", { args = { kind = "flank" } }),
						}),
						B.Sequence({
							B.Condition("AttackInRange"),
							B.Condition("AttackReady"),
							B.State("Attack"),
						}),
						B.Sequence({
							B.Condition("PounceReady"),
							B.State("Pounce"),
						}),
						B.State("Chase"),
					}),
				}),
				B.State("Orbit"),
			}),
		}),

		B.Sequence({
			B.Condition("FoodNearby"),
			B.State("Feed"),
		}),

		B.State("Wander"),
	})
end
