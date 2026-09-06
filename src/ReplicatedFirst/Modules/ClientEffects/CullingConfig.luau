
local CullingConfig = {}

CullingConfig.Enabled = true
CullingConfig.MaxDistance = 50

--@ Per-effect distance overrides, keyed by the lower-cased Effect path from the payload
--@ ("combat.weapons.staffvisuals", "forcefield"). Use for effects that read at range and
--@ should outlive the global cut. A value <= 0 disables culling for that path.
CullingConfig.DistanceOverrides = {
	--@ ["forcefield"] = 120,
}

--@ Effect paths that always play regardless of distance (lower-cased). Reserve for global
--@ cues that are not tied to a spot in the world.
CullingConfig.AlwaysPlay = {}

--@ Info keys searched, in order, for the effect's origin. Payloads are not uniform -- weapon
--@ visuals carry Info.Character, ForceField carries Info.Char -- so the origin is resolved by
--@ trying each key rather than assuming one. A key may hold a Model, BasePart, Attachment,
--@ CFrame or Vector3. Add new keys here as effects are added.
CullingConfig.OriginKeys = { "Character", "Char", "Origin", "Root", "Part", "Target", "Position" }

--@ An effect originating from the local player's own character always plays. You should never
--@ lose your own weapon visuals to a rounding error on your own position.
CullingConfig.AlwaysPlayLocal = true

--@ What to do when no origin can be resolved from the payload. Default false = play it
--@ (fail open), so adding an effect with an unrecognised Info shape degrades to the old
--@ behaviour instead of silently rendering nothing. Set true only if you would rather drop
--@ unplaceable effects than show them everywhere.
CullingConfig.CullUnresolved = false

return CullingConfig
