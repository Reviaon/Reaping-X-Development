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
			B.Action("AcquireTarget", { provoked = true }),
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
						B.Sequence({
							B.Condition("CryPoised"),
							B.State("Cry"),
						}),
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
				B.State("Flit"),
			}),
		}),

		B.Sequence({
			B.Condition("Startled"),
			B.State("FlyOff"),
		}),

		B.Sequence({
			B.Condition("Visiting"),
			B.Selector({
				B.Sequence({
					B.Condition("VisitStage", { stage = "circle" }),
					B.State("Escort"),
				}),
				B.Sequence({
					B.Condition("VisitStage", { stage = "greet" }),
					B.Selector({
						B.Sequence({
							B.Condition("Airborne"),
							B.State("Land"),
						}),
						B.State("Greet"),
					}),
				}),
				B.State("Follow"),
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
