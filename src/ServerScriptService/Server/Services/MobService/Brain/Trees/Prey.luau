return function(B)
	return B.Selector({
		B.Sequence({
			B.Condition("IsDisabled"),
			B.State("Disabled", { force = true }),
		}),

		B.Sequence({
			B.Condition("Asleep"),
			B.Selector({
				B.Sequence({
					B.Condition("Disturbed"),
					B.State("Wake"),
				}),
				B.State("Sleep"),
			}),
		}),

		B.Sequence({
			B.Condition("PredatorNear"),
			B.State("Evade"),
		}),

		B.Sequence({
			B.Condition("Wary"),
			B.State("Watch"),
		}),

		B.Sequence({
			B.Condition("Drowsy"),
			B.Selector({
				B.Sequence({
					B.Condition("AwayFromHome", { range = "home_radius" }),
					B.State("Return"),
				}),
				B.State("Sleep"),
			}),
		}),

		B.Sequence({
			B.Condition("AwayFromHome", { range = "wander_radius" }),
			B.State("Return"),
		}),

		B.State("Wander"),
	})
end
