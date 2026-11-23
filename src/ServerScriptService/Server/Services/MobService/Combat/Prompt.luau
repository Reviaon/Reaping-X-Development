--[[@
	**Prompt**: the interaction a mob offers the players beside it
	- **For now** it is Roblox's own ProximityPrompt; this module is the only place that knows, so the proper UI replaces it here and nothing else changes
	- **Offer:** `Prompt.Offer(mob, offer, answered)` puts it up `offer.offset` studs from the mob's root; `answered(character)` runs on the server for a living player who triggers it from within `offer.reach`
	- **One at a time:** a second offer replaces the first; `Prompt.Withdraw(mob)` takes it down, and it goes with the mob
]]
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")
local Perception = require("../Senses/Perception")

local NAME = "MobPrompt"
local REACH_SLACK = 4

local Prompt = {}

function Prompt.Withdraw(mob)
	local root = mob.Root
	local anchor = root and root:FindFirstChild(NAME)

	if anchor then
		anchor:Destroy()
	end
end

function Prompt.Offer(mob, offer: MobTypes.Offer, answered: (character: Model) -> ())
	local root = mob.Root
	if not root then return end

	Prompt.Withdraw(mob)

	local anchor = Instance.new("Attachment")
	anchor.Name = NAME
	anchor.Position = offer.offset or Vector3.zero

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = offer.action
	prompt.ObjectText = offer.object or ""
	prompt.MaxActivationDistance = offer.reach
	prompt.HoldDuration = offer.press or 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local from = Perception.RootOf(character)
		if not from or not Perception.IsValidTarget(character) then return end
		if (from.Position - anchor.WorldPosition).Magnitude > offer.reach + REACH_SLACK then return end

		answered(character)
	end)

	anchor.Parent = root
end

return Prompt
