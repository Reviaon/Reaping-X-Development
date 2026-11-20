--[[@
	**Attack stance**: the snake hunts along the ground, coils up hissing once its prey is close, and uncoils back to the ground when the prey is gone or far
	- **In:** `Curl` (Coil Up to Attack Idle) within `range`; out: `Uncoil` (Uncoil back down into Ground Idle) past `leave` or with no target
	- **While coiled:** the `Engaged` animations take over: the hissing idle, the stance slither, the stance repositions and the stance flinches
	- **Bite and constrict** start from the coil; the latch-on bites from the ground, rolled at the edge of `range` before it coils (`posture`)
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local stance: MobTypes.Stance = {
	range = 10, --@ Studs root to root; the latch-on's range, so the ground bite gets its roll first
	leave = 26, --@ Past its 13-stud ring and a 14-stud retreat hop, so only a fleeing player makes it uncoil and give chase along the ground
	enter = "Curl",
	exit = "Uncoil",
	enter_speed = 1.6, --@ The 1.83s coil-up takes about 1.1s
	exit_speed = 3, --@ The 4.58s uncoil takes about 1.5s before it chases on
	blend = 0.2, --@ Seconds before the clip ends that the stance or ground clips take over
}

return stance
