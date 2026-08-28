local Preset = {
	
	[Enum.Material.Grass] = {
		IDList = { 5639244517, 5639244517 }, 				-- 16975049722
		TimePosition = 0.3,
		Volume = 0.9,
	},
	
	[Enum.Material.Rock] = {
		IDList = { 180239559, 180239559, 180239559 },
		Volume = 0.85,
	},
	
	[Enum.Material.Sand] = {
		IDList = { 5639245918, 5639245918 }, 				-- 17027702755
		TimePosition = 0.2,
		Volume = 1.2,
	},
	
	[Enum.Material.Wood] = {
		IDList = { 2812419402, 2812419402 }, 				-- 17027712737
		TimePosition = 0.15,
		Volume = 0.4,
	},
	
	[Enum.Material.Metal] = {
		IDList = { 6214569720, 6214569720 }, 				-- 17027710965
		TimePosition = 0.1,
		Volume = 0.425,
	},
	
	VOLUME_MULTIPLIER = 0.3,
	
}

Preset[Enum.Material.Concrete] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Slate] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Brick] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Cobblestone] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Sandstone] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Rock] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Basalt] = Preset[Enum.Material.Rock]
Preset[Enum.Material.CrackedLava] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Asphalt] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Limestone] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Pavement] = Preset[Enum.Material.Rock]
Preset[Enum.Material.SmoothPlastic] = Preset[Enum.Material.Rock]
Preset[Enum.Material.ForceField] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Neon] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Granite] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Ice] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Glacier] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Fabric] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Ground] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Glass] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Pebble] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Mud] = Preset[Enum.Material.Rock]
Preset[Enum.Material.Plastic] = Preset[Enum.Material.Rock]
Preset[Enum.Material.SmoothPlastic] = Preset[Enum.Material.Rock]
----------------------
Preset[Enum.Material.CorrodedMetal] = Preset[Enum.Material.Metal]
Preset[Enum.Material.DiamondPlate] = Preset[Enum.Material.Metal]
Preset[Enum.Material.Foil] = Preset[Enum.Material.Metal]
----------------------
Preset[Enum.Material.LeafyGrass] = Preset[Enum.Material.Grass]
----------------------
Preset[Enum.Material.Salt] = Preset[Enum.Material.Sand]
Preset[Enum.Material.Snow] = Preset[Enum.Material.Sand]
----------------------
Preset[Enum.Material.WoodPlanks] = Preset[Enum.Material.Wood]


return Preset