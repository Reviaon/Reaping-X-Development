--[[@
	**Recovery config**: the universal get-up clip and how each trigger fades into it
	- **Sources:** one entry per trigger, found by name; a new trigger is a new entry plus a `RecoveryService.Play` call
	- **Lock:** `Status` holds the player still and action-locked (`StatusLibrary`) until `Release` seconds before the clip ends
]]
local Types = require("./Types")

return {
	Animation = "UniversalRecoveryAnimation", --@ Under Storage.Animations
	Priority = Enum.AnimationPriority.Action4,
	Speed = 1,
	FadeOut = 0.2, --@ Seconds, when stopped early
	Release = 0.15, --@ Seconds before the clip ends that control returns
	FallbackLength = 1, --@ Seconds locked when the clip length isn't loaded yet
	Status = "IsGettingUp",
	StatusSource = "Recovery",
	TailAttribute = "RagdollTail", --@ RagdollR6 seconds of pose stream after a ragdoll; 0 hands observers straight to this clip
	Tail = 0,

	Sources = {
		Ragdoll = { FadeIn = 0.1 }, --@ RagdollService status ends
		TackleMiss = { FadeIn = 0.2 }, --@ Cross-fades from the held TackleMiss pose
	},
} :: Types.Config
