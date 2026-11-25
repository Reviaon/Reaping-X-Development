local Types = require("./Types")

return {
	Assets = { "Storage", "Particles", "MovementVFX", "Footstep" }, --@ Under ReplicatedStorage; one part of emitters per kind of ground
	Pebble = { "Storage", "Particles", "MovementVFX", "DashGroundDebree", "Ground" }, --@ Under ReplicatedStorage; the block every pebble is cut from
	Visuals = { "World", "Visuals" }, --@ Under Workspace; where pooled prints and pebbles live

	Kinds = { --@ Kind -> its part under `Assets`; a new kind is a new part and a line here
		Grass = "grass gray",
		Sand = "sand gray",
		Ground = "ground gray",
	},
	Fallback = "Ground", --@ Kind for any floor material not listed below
	Materials = { --@ Floor material -> kind
		[Enum.Material.Grass] = "Grass",
		[Enum.Material.LeafyGrass] = "Grass",
		[Enum.Material.Sand] = "Sand",
	},

	Legs = { "Left Leg", "Right Leg" }, --@ R6 limbs whose tips plant; a body without them is never watched
	Range = 120, --@ Studs from the camera characters get footsteps within
	MinSpeed = 2, --@ Studs/s across the floor a character must move for its feet to plant
	Reach = 0.25, --@ Studs a foot must swing ahead of its hip, along the way it's moving, before its plant counts
	Drop = 0.05, --@ Studs a foot must fall back from its furthest reach to plant, so one swing is one step
	Rearm = 0, --@ The foot must pass back under its hip (this far ahead or less) before it can plant again
	RayUp = 1, --@ Studs above a foot the floor probe starts
	RayDepth = 6, --@ Studs the floor probe reaches down

	Sounds = { --@ A step sound from the planted leg, picked by the ground's kind and the speed
		Kinds = { --@ Kind -> SoundLibrary path the gait name is added to; a kind left out is silent
			Grass = "Footsteps.Grass",
			Sand = "Footsteps.Sand",
			Ground = "Footsteps.Stone",
		},
		RunSpeed = 22, --@ Studs/s across the floor a step counts as running (`.Run`), under it walking (`.Walk`)
		Mute = { "Running" }, --@ Roblox's default character sounds on the root, silenced on watched bodies so steps aren't doubled
	},

	PrintPool = 8, --@ Copies of each kind's part, used in turn, so a recolour never repaints prints still fading

	Pebbles = { --@ Tiny blocks kicked up behind a sprinting character's planted foot
		Speed = 22, --@ Studs/s across the floor that counts as sprinting (sprint walks at 30, a walk at most 16)
		Count = NumberRange.new(2, 3),
		Size = NumberRange.new(0.1, 0.22), --@ Studs per side
		Back = NumberRange.new(5, 9), --@ Studs/s flung back against the run
		Up = NumberRange.new(5, 8), --@ Studs/s flung up
		Spread = math.rad(30), --@ Most a pebble strays off straight behind
		Gravity = 70, --@ Studs/s² pulling them down; under the world's, so the arc reads
		Lifetime = 0.45, --@ Seconds a pebble lives
		Shrink = 0.15, --@ Seconds at the end it shrinks away
		Lift = 0.15, --@ Studs above the floor it starts
		Pool = 40,
		PoolGrowth = 20,
	},
} :: Types.Config
