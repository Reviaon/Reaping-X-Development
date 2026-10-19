local BlockLibrary = require("./BlockLibrary")

return{
	--@ TODO: Build within server controller. These are just placeholders for now.

	--@ Combat
	["ComboCount"] = 0,
	[BlockLibrary.HealthAttribute] = BlockLibrary.MaxHealth,
	[BlockLibrary.MaxHealthAttribute] = BlockLibrary.MaxHealth,

	--@ Movement
	["Stamina"] = 100,
	["MaxStamina"] = 100,

}