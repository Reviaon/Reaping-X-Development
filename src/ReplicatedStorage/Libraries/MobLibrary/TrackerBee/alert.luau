--[[@
	**Alert**: on spotting prey it hangs in the air and rages before it hunts
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local alert: MobTypes.Alert = {
	animation = "Rage",
	visual = "Rage", --@ TrackerBeeVisuals: the head and torso rage
	cooldown = 20, --@ Seconds before a new target makes it rage again
}

return alert
