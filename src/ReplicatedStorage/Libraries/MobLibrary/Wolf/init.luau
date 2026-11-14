--[[@
	**Wolf**: a pack hunter that circles, bites in a four-hit combo, and leaps in from the fight's edge
	- **Assembled by name:** each child module fills the key it is named after (`MobService/Config.Gather`)
	  - `attack`: the bite combo
	  - `abilities/<key>`: one module per ability; other config refers to an ability by its key
	  - `rally`, `feed`, `ragdoll`, `animations`: one behaviour each
	- **This module:** identity, body and small settings; anything left out comes from `MobService/Defaults`
]]
return {
	template = "Wolf", --@ ServerStorage.Mobs model
	scale = 0.8, --@ ScaleTo factor, applied once to the prototype
	health = 120,
	run_speed = 50, --@ Chase speed
	spawn = { group = { 3, 4 } }, --@ Pack size per zone spawn

	dash = {
		visual = "Dash", --@ WolfVisuals dust per dash
	},

	visuals = "Combat.Mobs.WolfVisuals", --@ Effects module for every timeline the submodules name

	idle_actions = { "Inspect" }, --@ Played between roams
	hurt_animations = { "Hurt1", "Hurt2", "Hurt3" }, --@ One at random per hit taken

	rig = {
		root_scale = Vector3.new(0.7, 0.35, 0.5), --@ HumanoidRootPart, as a share of the scaled bounds
		hip_ratio = 0.3, --@ HipHeight, as a share of the scaled height
	},

	animation_speeds = { --@ Locomotion playback multipliers on top of the speed match
		Run = 1.5,
	},

	animation_exclusive = { --@ Locomotion keys that never blend
		{ "WalkLeft", "WalkRight" },
	},
}
