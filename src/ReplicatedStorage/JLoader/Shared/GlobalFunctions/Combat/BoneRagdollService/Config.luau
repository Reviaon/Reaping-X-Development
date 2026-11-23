return {
	Tag = "BoneRagdoll", --@ CollectionService tag on a ragdolled body; clients pose its bones while it is on
	Attribute = "BoneRagdolled", --@ Set true on a ragdolled body; ChronoConfig.PauseStatuses lists it so Chrono stops moving the root
	FolderName = "BoneRagdoll", --@ Holds the body's segments
	DriveAttribute = "BoneRagdollDrive", --@ Marks a segment attachment that a bone of the same name follows
	Thickness = 1, --@ Studs across a segment whose definition gives none, before the model's scale
	Padding = 0, --@ Studs added to a segment's length when its definition gives none, before the model's scale
	Cone = 50, --@ Degrees a joint bends from its pose at death when its definition gives none
	Twist = 25, --@ Degrees a joint twists each way when its definition gives none
	Friction = 0.05, --@ Joint friction as a share of the torque gravity puts on the child segment held out level (mass x gravity x half its length), so a rabbit's leg hangs as loose as a wolf's; a segment's `friction` overrides it
	Physical = PhysicalProperties.new(0.7, 0.9, 0, 1, 1), --@ Grippy and dead, so the body settles where it falls
	PinInterval = 0.5, --@ Seconds between pinning the segments back to the server
	StandHeightAttribute = "MobRootHeight", --@ Root height above the ground a knocked-down body stands back up at; MobService sets it
	GroundProbe = 12, --@ Studs below the body searched for ground when it stands back up
	AirGravity = 0.55, --@ Share of gravity a knocked-down body falls with until it lands, as players' RagdollR6 AIR profile, so mobs arc like players; a finisher's `gravity` overrides it
	LandReach = 0.6, --@ Studs past its own size below the first segment that count as landed, ending the lighter fall
}
