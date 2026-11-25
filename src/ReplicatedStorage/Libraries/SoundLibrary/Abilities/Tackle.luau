--[[@
	**Tackle**: the run-jump dive (`CharacterLibrary.TackleLibrary`)
	- **Found by:** `Abilities.Tackle.<Name>`
	- **Miss:** the dive landing on nobody, alongside the `TackleMiss` clip
	- **FacePunch:** each punch to the face of a victim dived on from the front (`Grapples.Front`)
	- **FaceSlam:** each slam of the face into the ground of a victim dived on from behind (`Grapples.Back`)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Tackle: SoundTypes.Group = {
	Miss = { Ids = { 121991649427390 } }, --@ Jump dive miss
	FacePunch = { Ids = { 72333143213007 } }, --@ Face punch
	FaceSlam = { Ids = { 124894588944045 } }, --@ Face slam
}

return Tackle
