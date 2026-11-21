return function(B)
	return B.Selector({
		B.Sequence({
			B.Condition("IsDisabled"),
			B.State("Disabled", { force = true }),
		}),

		B.Sequence({
			B.Condition("IsReturning"),
			B.Selector({
				B.Sequence({
					B.Condition("Airborne"),
					B.State("Land"),
				}),
				B.State("Return"),
			}),
		}),

		B.Sequence({
			B.Action("AcquireTarget"),
			B.Selector({
				B.Sequence({
					B.Condition("BeyondLeash"),
					B.Action("BeginReturn"),
					B.State("Land"),
				}),
				B.Sequence({
					B.Condition("CryReady"),
					B.Selector({
						B.Sequence({
							B.Condition("LandToCry"),
							B.State("Land"),
						}),
						B.State("Cry"),
					}),
				}),
				B.Sequence({
					B.Condition("SwoopDue"),
					B.Selector({
						B.Sequence({
							B.Condition("Airborne"),
							B.State("Land"),
						}),
						B.Sequence({
							B.Condition("AttackInRange"),
							B.Condition("AttackReady"),
							B.State("Attack"),
						}),
						B.State("Chase"),
					}),
				}),
				B.State("Circle"),
			}),
		}),

		B.Sequence({
			B.Condition("Airborne"),
			B.State("Land"),
		}),

		B.Sequence({
			B.Condition("AwayFromHome"),
			B.Action("BeginReturn"),
			B.State("Return"),
		}),

		B.State("Wander"),
	})
end
