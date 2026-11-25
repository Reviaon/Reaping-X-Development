--[[@
	**Grab**: the chokehold (`PushLibrary.Grab`, the `IsChoking` / `IsChoked` pair)
	- **Found by:** `Abilities.Grab.<Name>`
	- **Hit:** the hold taking; **Loop:** the choking while it's held, looped until stopped
	- **Endings:** `Fail` when the holder loses (the victim breaks free), `NeckDamaged` when the victim loses
]]
local SoundTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Effects/SoundTypes")

local Grab: SoundTypes.Group = {
	Hit = { Ids = { 128658251312412 } }, --@ Choke hold hit
	Loop = { Ids = { 79498869947877 }, Looped = true }, --@ Choking loop
	Fail = { Ids = { 72596514490993 } }, --@ Choking fail
	NeckDamaged = { Ids = { 117042635682173 } }, --@ NeckDamaged
}

return Grab
