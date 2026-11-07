return {
	Radius = 120, --@ Studs around the caller a mob must be within to be inspected
	StateAttribute = "MobState", --@ Set on every mob model to its current state name
	Sections = { "State", "Threat", "Sight", "Path", "Team" }, --@ Report order when no section is named
	Overhead = { { "State", "Threat", "Sight" }, { "Team", "Path" } }, --@ Rows of section briefs shown over each mob while debug mode is on
	Separator = " · ", --@ Joins the briefs within one overhead row
}
