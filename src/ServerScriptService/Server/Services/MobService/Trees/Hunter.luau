return function(B)
	return B.Selector({
		B.Sequence({
			B.Condition("IsDisabled"),
			B.State("Disabled", { force = true }),
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
					B.Action("ClaimAttackSlot"),
					B.Selector({
						B.Sequence({
							B.Condition("TargetInRange", { range = "attack_range" }),
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

		B.State("Wander"),
	})
end
