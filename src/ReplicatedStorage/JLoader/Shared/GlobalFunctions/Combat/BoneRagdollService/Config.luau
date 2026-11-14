return {
	Tag = "BoneRagdoll", --@ CollectionService tag on a ragdolled body; clients pose its bones while it is on
	Attribute = "BoneRagdolled", --@ Set true on a ragdolled body; ChronoConfig.PauseStatuses lists it so Chrono stops moving the root
	FolderName = "BoneRagdoll", --@ Holds the body's segments
	DriveAttribute = "BoneRagdollDrive", --@ Marks a segment attachment that a bone of the same name follows
	Thickness = 1, --@ Studs across a segment whose definition gives none, before the model's scale
	Padding = 0, --@ Studs added to a segment's length when its definition gives none, before the model's scale
	Cone = 35, --@ Degrees a joint bends from its pose at death when its definition gives none
	Twist = 20, --@ Degrees a joint twists each way when its definition gives none
	FrictionPerMass = 12, --@ Joint friction torque per unit of the child segment's mass, so heavy and light bodies damp alike
	Physical = PhysicalProperties.new(0.7, 0.9, 0, 1, 1), --@ Grippy and dead, so the body settles where it falls
	PinInterval = 0.5, --@ Seconds between pinning the segments back to the server
}
