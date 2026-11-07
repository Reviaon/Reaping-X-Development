local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("./Config")
local Weapon = require("./Weapon")
local Aim = require("./Aim")
local Nock = require("./Nock")

local Shot = {}

local shotCounter = 0
local hitEffects = nil

local function hits()
	if not hitEffects then
		local ok, module = pcall(require, ReplicatedStorage.Modules.Effects.Combat.Hit)

		if ok then
			hitEffects = module
		end
	end

	return hitEffects
end

local function surfaceColor(result: RaycastResult): Color3?
	local hit = result.Instance

	if hit == workspace.Terrain then
		local ok, color = pcall(workspace.Terrain.GetMaterialColor, workspace.Terrain, result.Material)
		return if ok then color else nil
	end

	return if hit and hit:IsA("BasePart") then hit.Color else nil
end

local function spawnObstacle(projectile, result: RaycastResult)
	local name = projectile.obstacle_effect
	local module = typeof(name) == "string" and hits()

	if module then
		module.SpawnParticles(nil, name, result.Position, result.Normal, surfaceColor(result))
	end
end

local function victimOf(instance: Instance?): Model?
	local world = workspace:FindFirstChild("World")
	local living = world and world:FindFirstChild("Live")
	local model = instance

	while model and model.Parent ~= living do
		model = model.Parent
	end

	return if model and model:IsA("Model") then model else nil
end

function Shot.Build(controller, state, projectile)
	local root = controller.HumanoidRootPart
	if not root then return nil end

	local arrow = Nock.Arrow(state, projectile)
	local origin = if arrow
		then arrow.CFrame * Vector3.new(arrow.Size.X / 2, 0, 0)
		else root.Position + Vector3.yAxis * Config.FallbackOriginHeight

	local direction = (state.aimPoint or Aim.Point(controller, projectile)) - origin

	if direction.Magnitude < Config.MinShotDistance then
		direction = root.CFrame.LookVector
	end

	return controller.ProjectileService.NewShot(origin, direction, projectile, controller.Character)
end

function Shot.Fire(controller, state, projectile)
	local shot = Shot.Build(controller, state, projectile)
	if not shot then return end

	shotCounter += 1

	local id = shotCounter
	local relay = controller.RangedRelay

	state.lastShot = shot

	if relay then
		relay.ReportShot:Fire((Weapon.Of(controller)), shot.Origin, shot.Direction, shot.FiredAt, id)
	end

	controller.ProjectileService.Fire(shot, {
		onHit = function(result: RaycastResult, at: number)
			local victim = victimOf(result.Instance)

			if not victim then
				spawnObstacle(projectile, result)
			elseif relay then
				relay.ReportProjectileHit:Fire(id, victim, result.Position, at, result.Instance.Name)
			end
		end,
	})
end

function Shot.Observe(controller, shooter, weaponId, origin, direction, firedAt)
	if shooter == controller.Character then return end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(firedAt) ~= "number" then return end

	local config = controller.CombatConfig
	local data = config and typeof(weaponId) == "string" and config.WeaponConfig[weaponId]
	if not data or not data.projectile then return end

	local shot = controller.ProjectileService.NewShot(origin, direction, data.projectile, if typeof(shooter) == "Instance" then shooter else nil)
	shot.FiredAt = firedAt

	controller.ProjectileService.Fire(shot, {
		elapsed = math.clamp(workspace:GetServerTimeNow() - firedAt, 0, Config.MaxCatchUp),
		onHit = function(result: RaycastResult)
			if not victimOf(result.Instance) then
				spawnObstacle(data.projectile, result)
			end
		end,
	})
end

return Shot
