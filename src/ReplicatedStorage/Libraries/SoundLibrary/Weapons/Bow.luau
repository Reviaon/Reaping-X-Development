--[[@
	**Bow**: drawing, loading and loosing the bow, and arrows landing
	- **Found by:** `Weapons.Bow.<Name>`
	- **Shots:** `QuickFire` for an early release, `ChargedShot` for a full draw
	- **Impact:** keyed by what the arrow struck (`Weapons.Bow.Impact.Rock`)
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Bow: SoundTypes.Group = {
	Charge = { Ids = { 80907513294959 } }, --@ Bow charge
	Load = { Ids = { 87352756693564 } }, --@ Arrow load
	QuickFire = { Ids = { 127720667784750 } }, --@ Arrow quick fire
	ChargedShot = { Ids = { 107395031178056 } }, --@ Arrow full charged shot

	Impact = {
		Wood = { Ids = { 136753087422927 } }, --@ Arrow wood hit
		Sand = { Ids = { 109164594138951 } }, --@ Arrow sand hit
		Rock = { Ids = { 101714902725541 } }, --@ Arrow rock hit
	} :: SoundTypes.Group,
}

return Bow
