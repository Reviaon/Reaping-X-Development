return {
	--@ Read off the Tool when it is equipped, and published on the character by the server
	Attribute = "Tier",
	EquippedAttribute = "EquippedTier",

	--@ What a weapon is when its Tool names no tier, or one that weapon has no model for
	Default = "Wooden",

	--@ The tier a weapon's rig is authored in: its own mesh is used as is. Every other tier swaps in
	--@ Storage.Models.Weapons.<Weapon>.<Tier>, matched to the rig mesh's position and orientation
	--@ and held by the same joint
	Native = "Diamond",

	Order = { "Wooden", "Stone", "Diamond" },

	--@ Damage multiplies the weapon's base_damage. Weight is how often the tier should turn up
	--@ when weapons are handed out at random
	Tiers = {
		Wooden = { Damage = 1, Weight = 70 },
		Stone = { Damage = 1.5, Weight = 25 },
		Diamond = { Damage = 2, Weight = 5 },
	},
}
