local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local CollisionService = Jloader.CreateService({ Name = script.Name })

CollisionService.Settings = {
	--@ Every group this game adds. A group not named here is not registered.
	Groups = { "Players", "Mobs", "Ragdoll", "RagdollBody" },

	--@ Pairs that pass through each other. Anything not listed collides as usual.
	--@ Ragdoll is the limb colliders, RagdollBody a character's own parts while it is ragdolled
	--@ (RagdollService moves them there and back). The colliders touch a ragdolled body and the
	--@ map, and nothing else: not a standing player or mob, and not each other.
	Apart = {
		{ "Players", "Players" },
		{ "Players", "Mobs" },
		{ "Mobs", "Mobs" },

		{ "Ragdoll", "Players" },
		{ "Ragdoll", "Mobs" },
		{ "Ragdoll", "Ragdoll" },

		{ "RagdollBody", "Players" },
		{ "RagdollBody", "Mobs" },
		{ "RagdollBody", "RagdollBody" },
	},

	PlayerGroup = "Players",
	MobGroup = "Mobs", --@ Any other Humanoid model in World.Live

	--@ Parts kept out of their character's group, by name. The ragdoll's limb colliders have to keep
	--@ colliding with their own body, which a group that is apart from itself would stop.
	Overrides = {
		["@ragdoll"] = "Ragdoll",
	},
}

for _, group in CollisionService.Settings.Groups do
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
end

for _, pair in CollisionService.Settings.Apart do
	PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
end

local function place(part: Instance, group: string)
	if part:IsA("BasePart") then
		part.CollisionGroup = CollisionService.Settings.Overrides[part.Name] or group
	end
end

function CollisionService.Assign(instance: Instance, group: string, watch: boolean?): RBXScriptConnection?
	place(instance, group)

	for _, part in instance:GetDescendants() do
		place(part, group)
	end

	if not watch then return nil end

	return instance.DescendantAdded:Connect(function(part)
		place(part, group)
	end)
end

function CollisionService:Load()
	local settings = self.Settings
	local live = workspace:WaitForChild("World"):WaitForChild("Live")

	local function watchPlayer(player: Player)
		if player.Character then
			CollisionService.Assign(player.Character, settings.PlayerGroup, true)
		end

		player.CharacterAdded:Connect(function(character)
			CollisionService.Assign(character, settings.PlayerGroup, true)
		end)
	end

	local function watchMob(model: Instance)
		if not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then return end
		if not model:FindFirstChildOfClass("Humanoid") then return end

		CollisionService.Assign(model, settings.MobGroup, true)
	end

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	Players.PlayerAdded:Connect(watchPlayer)

	for _, model in live:GetChildren() do
		watchMob(model)
	end

	live.ChildAdded:Connect(function(child)
		task.defer(watchMob, child)
	end)
end

return CollisionService
