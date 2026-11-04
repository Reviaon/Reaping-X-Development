local Config = require("./Config")

local Weapon = {}

function Weapon.Of(controller)
	local config = controller.CombatConfig
	local id = config and config:ResolveEquippedWeapon(controller)
	local data = id and config.WeaponConfig[id]

	return id, data and data.projectile
end

function Weapon.AnimationName(id: string, projectile, key: string): string
	local named = typeof(projectile.animations) == "table" and projectile.animations[key]
	return if typeof(named) == "string" then named else id .. Config.DefaultAnimations[key]
end

function Weapon.Cancelled(controller): boolean
	local Character = controller.Character
	local Humanoid = controller.Humanoid

	if not Character or not Humanoid or Humanoid.Health <= 0 then return true end
	if controller.StatusService:CheckStatuses(Character, Config.CancelOn) then return true end
	if controller.StatusService:IsHitYielded(Character) then return true end

	return controller.PairSceneService.IsInScene(Character)
end

return Weapon
