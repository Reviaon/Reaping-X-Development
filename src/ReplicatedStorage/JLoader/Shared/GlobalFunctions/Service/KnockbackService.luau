local KnockbackService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PhysicsService = require(script.Parent:WaitForChild("PhysicsService"))
local PositionService = require(script.Parent:WaitForChild("PositionService"))
local WorldConstants = require(script.Parent.Parent:WaitForChild("WorldConstants"))

KnockbackService.Settings = {
	--@ Fixed integration steps for the displacement curve. Same count on every machine, so every
	--@ machine lands on the same numbers.
	CurveSamples = 64,

	--@ Seconds a non-owning client eases from its finished drive onto the replicated position.
	HandoffBlend = 0.1,

	--@ Studs kept between a wall the blockcast hit and the clamped finish.
	WallPadding = 0.5,

	--@ Fraction of the knockback over which the victim turns to face the attacker.
	FacingPortion = 0.35,

	--@ Impulse priority the drive claims on the root, so a dash cannot take over mid-knockback.
	Priority = 5,

	--@ Whether the drive lifts the victim over ground that rises under the push. Off leaves Y to
	--@ physics entirely, which clips into slopes at WalkSpeed 0.
	FollowGround = true,

	--@ Studs of rise the drive will step the victim up in one frame. Anything taller is a wall.
	MaxStepUp = 2,

	--@ Studs below the expected foot height the ground probe still looks, for small dips.
	GroundProbe = 1,

	--@ Studs above the ground a root may sit at build time and still count as standing. Higher is
	--@ airborne and the drive leaves Y alone for that knockback.
	AirborneOffset = 4.5,

	--@ Attributes stamped on the root while a drive runs. PhysicsService reads them.
	PriorityAttribute = "knockback_priority",
	UntilAttribute = "knockback_until",
}

local active = setmetatable({}, { __mode = "k" })
local drives = setmetatable({}, { __mode = "k" })
local curves = setmetatable({}, { __mode = "k" })
local connection = nil
local nextId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function speedAt(curve, elapsed: number): number
	local duration = curve.duration
	if elapsed < 0 or elapsed > duration then return 0 end

	local falloff = curve.falloff or duration
	local rampIn = math.max(curve.rampIn or 0, 0)

	local alpha = falloff > 0 and math.clamp(elapsed / falloff, 0, 1) or 1
	local current = curve.speed * (1 - alpha)
	local ramp = rampIn > 0 and math.min(elapsed / rampIn, 1) or 1

	return current * ramp
end

function KnockbackService.Table(curve)
	local samples = KnockbackService.Settings.CurveSamples
	local step = curve.duration / samples
	local cumulative = table.create(samples + 1)
	local total = 0

	cumulative[1] = 0

	for index = 1, samples do
		local before = (index - 1) * step
		local after = index * step
		total += (speedAt(curve, before) + speedAt(curve, after)) * 0.5 * step
		cumulative[index + 1] = total
	end

	return cumulative, total
end

local function progress(cumulative, total: number, curve, elapsed: number): number
	if total <= 0 then return 1 end
	if elapsed <= 0 then return 0 end
	if elapsed >= curve.duration then return 1 end

	local samples = #cumulative - 1
	local scaled = elapsed / curve.duration * samples
	local index = math.floor(scaled)
	local fraction = scaled - index

	local lower = cumulative[index + 1]
	local upper = cumulative[math.min(index + 2, #cumulative)]

	return (lower + (upper - lower) * fraction) / total
end

--@ The curve table lives beside the recipe rather than on it, so the recipe that goes over the
--@ wire is only what a client needs to rebuild it.
function KnockbackService.Progress(recipe, at: number): number
	local cached = curves[recipe]

	if not cached then
		local cumulative, total = KnockbackService.Table(recipe.curve)
		cached = { cumulative = cumulative, total = total }
		curves[recipe] = cached
	end

	return progress(cached.cumulative, cached.total, recipe.curve, at - recipe.startTime)
end

function KnockbackService.Evaluate(recipe, at: number)
	local elapsed = at - recipe.startTime
	local alpha = KnockbackService.Progress(recipe, at)
	local position = recipe.start:Lerp(recipe.finish, alpha)

	local facingWindow = recipe.curve.duration * KnockbackService.Settings.FacingPortion
	local turn = facingWindow > 0 and math.clamp(elapsed / facingWindow, 0, 1) or 1

	return position, turn, elapsed >= recipe.curve.duration
end

function KnockbackService.Active(victim)
	local recipe = active[victim]

	if recipe and now() < recipe.startTime + recipe.curve.duration then
		return recipe
	end

	return nil
end

--@ Both sides. Everything a machine needs to draw a knockback, decided once so every machine
--@ draws the same one: the start is `previous` evaluated at this instant if one is still running
--@ — a chain stays deterministic because a trajectory is a pure function of time — the finish is
--@ blockcast against the map so a wall clamps it here rather than on each client, and the clock is
--@ server time so a late packet joins the motion in progress.
function KnockbackService.Compose(character, direction: Vector3, knockback, facing: Vector3?, previous, options)
	local root = rootOf(character)
	if not root then return nil end

	direction = flat(direction)
	if direction.Magnitude <= 0 then return nil end
	direction = direction.Unit

	options = options or {}

	local startTime = now()
	local start

	--@ A steered recipe's path is wherever its driver took it, so its position is not a function
	--@ of time; the live root is the truth for one.
	if previous and not previous.steer then
		start = KnockbackService.Evaluate(previous, startTime)
	else
		start = PositionService.Reference(character) or root.Position
	end

	local origin = Vector3.new(start.X, root.Position.Y, start.Z)

	local curve = {
		speed = knockback.speed,
		duration = knockback.duration,
		falloff = knockback.falloff,
		rampIn = knockback.rampIn,
	}

	local _, total = KnockbackService.Table(curve)
	local distance = knockback.distance or total

	--@ A steered recipe has no fixed finish to clamp; it checks the wall it is actually heading at
	--@ every frame instead.
	if not options.steer then
		local result = workspace:Blockcast(CFrame.new(origin), root.Size, direction * distance, WorldConstants.world_ray_params)

		if result then
			distance = math.max(result.Distance - KnockbackService.Settings.WallPadding, 0)
		end
	end

	--@ How high this rig's root sits above the ground when standing, measured here so every client
	--@ follows the slope by the same amount. Nil means airborne, and Y is left to physics.
	local groundOffset = nil
	local settings = KnockbackService.Settings
	local probe = workspace:Raycast(root.Position, Vector3.new(0, -(settings.AirborneOffset + settings.GroundProbe), 0), WorldConstants.world_ray_params)

	if probe then
		local measured = root.Position.Y - probe.Position.Y

		if measured <= settings.AirborneOffset then
			groundOffset = measured
		end
	end

	return {
		start = flat(origin),
		finish = flat(origin) + direction * distance,
		facing = facing and flat(facing).Magnitude > 0 and flat(facing).Unit or nil,
		startTime = startTime,
		curve = curve,
		priority = knockback.priority or KnockbackService.Settings.Priority,
		groundOffset = groundOffset,
		distance = distance,
		direction = direction,
		steer = options.steer == true or nil,
		influence = options.steer and math.max(knockback.influence or 0, 0) or nil,
	}
end

--@ Server side. A knockback the server decides and every client will be told about. Numbered so a
--@ client can drop one that arrives behind a newer one.
function KnockbackService.Build(victim, direction: Vector3, knockback, facing: Vector3?)
	if not RunService:IsServer() then return nil end

	local recipe = KnockbackService.Compose(victim, direction, knockback, facing, KnockbackService.Active(victim))
	if not recipe then return nil end

	nextId += 1
	recipe.id = nextId
	active[victim] = recipe

	return recipe
end

--@ Client side, own character only. A lunge is the same recipe a knockback is, built from the same
--@ curve, so with no input an attacker's forward step and their victim's shove cover the same
--@ studs by construction. It is steered: the curve's speed is spent along the character's look
--@ each frame, and their own walking is folded in by `influence`, so an attacker who moves during
--@ the swing moves — they were never going to stand still to stay aligned. Nobody else needs
--@ telling: the attacker owns their character, and their CFrame writes are what replication
--@ carries, which is also why the lunge is free to be non-deterministic when the shove is not.
function KnockbackService.Lunge(character, direction: Vector3, impulse)
	if not RunService:IsClient() then return nil end
	if character ~= Players.LocalPlayer.Character then return nil end

	local recipe = KnockbackService.Compose(character, direction, impulse, nil, KnockbackService.Active(character), {
		steer = true,
	})
	if not recipe then return nil end

	if not KnockbackService.Apply(character, recipe) then return nil end

	return recipe
end

local function shouldDrive(victim): (boolean, boolean)
	local owner = Players:GetPlayerFromCharacter(victim)

	if RunService:IsServer() then
		return owner == nil, true
	end

	return true, owner ~= nil and owner == Players.LocalPlayer
end

local function finish(victim, drive)
	drives[victim] = nil

	local root = drive.root

	if root.Parent then
		root:SetAttribute(KnockbackService.Settings.PriorityAttribute, nil)
		root:SetAttribute(KnockbackService.Settings.UntilAttribute, nil)
	end

	local humanoid = drive.humanoid

	if drive.isOwner and humanoid and humanoid.Parent and drive.autoRotate ~= nil then
		humanoid.AutoRotate = drive.autoRotate
	end

	if next(drives) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

--@ Y the root should sit at over the ground under (x, z), or nil to leave it alone. Only ever
--@ lifts: level or falling ground returns nil so drops and gravity stay with physics, and a rise
--@ taller than MaxStepUp is a wall the blockcast should already have stopped short of.
local function groundLift(drive, x: number, z: number, currentY: number): number?
	local settings = KnockbackService.Settings
	local offset = drive.recipe.groundOffset

	if not settings.FollowGround or not offset then return nil end

	local origin = Vector3.new(x, currentY + settings.MaxStepUp, z)
	local length = settings.MaxStepUp + offset + settings.GroundProbe
	local result = workspace:Raycast(origin, Vector3.new(0, -length, 0), WorldConstants.world_ray_params)

	if not result then return nil end

	local desired = result.Position.Y + offset
	if desired <= currentY then return nil end

	return math.min(desired, currentY + settings.MaxStepUp)
end

local function write(drive, position: Vector3, turn: number)
	local root = drive.root
	local live = root.CFrame

	local rotation = live.Rotation

	if drive.targetRotation then
		rotation = drive.startRotation:Lerp(drive.targetRotation, turn)
	end

	local y = live.Position.Y
	local lifted = groundLift(drive, position.X, position.Z, y)

	if lifted then
		y = lifted
	end

	root.CFrame = CFrame.new(position.X, y, position.Z) * rotation

	if drive.isOwner then
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, lifted and 0 or velocity.Y, 0)
	end
end

local function step()
	local at = now()

	for victim, drive in drives do
		local root = drive.root

		if not victim.Parent or not root.Parent then
			finish(victim, drive)
			continue
		end

		local recipe = drive.recipe

		if recipe.steer then
			local alpha = KnockbackService.Progress(recipe, at)
			local delta = (alpha - drive.lastAlpha) * recipe.distance
			local dt = at - drive.lastAt
			drive.lastAlpha = alpha
			drive.lastAt = at

			local look = flat(root.CFrame.LookVector)
			look = look.Magnitude > 0 and look.Unit or recipe.direction

			local stepVector = look * delta
			local humanoid = drive.humanoid

			if humanoid and recipe.influence > 0 then
				local move = flat(humanoid.MoveDirection)

				if move.Magnitude > 0 then
					stepVector += move.Unit * humanoid.WalkSpeed * recipe.influence * dt
				end
			end

			if stepVector.Magnitude > 0 then
				local hit = workspace:Blockcast(root.CFrame, root.Size, stepVector, WorldConstants.world_ray_params)

				if hit then
					stepVector = stepVector.Unit * math.max(hit.Distance - KnockbackService.Settings.WallPadding, 0)
				end
			end

			write(drive, flat(root.Position) + stepVector, 1)

			if alpha >= 1 then
				finish(victim, drive)
			end

			continue
		end

		local position, turn, done = KnockbackService.Evaluate(recipe, at)

		if not done then
			write(drive, position, turn)
			continue
		end

		if drive.isOwner then
			write(drive, position, 1)
			finish(victim, drive)
			continue
		end

		if not drive.finishedAt then
			drive.finishedAt = at
		end

		local blend = (at - drive.finishedAt) / math.max(KnockbackService.Settings.HandoffBlend, 1e-3)

		if blend >= 1 then
			finish(victim, drive)
			continue
		end

		local live = root.Position
		local target = Vector3.new(recipe.finish.X, live.Y, recipe.finish.Z)
		write(drive, target:Lerp(live, blend), 1)
	end
end

--@ Both sides. Records the recipe as the victim's current knockback, and drives the root if this
--@ machine is the one that should: every client draws every victim, the server draws only what it
--@ owns. A client writing a character it does not own is local and wins the frame; the owner
--@ writing the same trajectory is what replication carries, so the two agree where it ends.
function KnockbackService.Apply(victim, recipe)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return false end
	if typeof(recipe) ~= "table" or typeof(recipe.start) ~= "Vector3" then return false end

	local root = rootOf(victim)
	if not root then return false end

	local current = active[victim]

	if current and current ~= recipe then
		if current.id and recipe.id and recipe.id <= current.id then
			return false
		end

		if KnockbackService.Active(victim) and (recipe.priority or 0) < (current.priority or 0) then
			return false
		end
	end

	active[victim] = recipe

	local drive, isOwner = shouldDrive(victim)
	if not drive then return true end

	local existing = drives[victim]
	local autoRotate = existing and existing.autoRotate
	local humanoid = victim:FindFirstChildOfClass("Humanoid")

	if existing then
		existing.autoRotate = nil
		finish(victim, existing)
	end

	PhysicsService.ClearExistingImpulse({ Character = victim })

	--@ A steered drive leaves AutoRotate alone: the Humanoid turning the root toward the move
	--@ direction is exactly what steers it.
	if isOwner and humanoid and not recipe.steer then
		if autoRotate == nil then
			autoRotate = humanoid.AutoRotate
		end

		humanoid.AutoRotate = false
	end

	local startRotation = root.CFrame.Rotation
	local targetRotation = nil

	if recipe.facing then
		targetRotation = CFrame.lookAt(Vector3.zero, recipe.facing).Rotation
	end

	root:SetAttribute(KnockbackService.Settings.PriorityAttribute, recipe.priority)
	root:SetAttribute(KnockbackService.Settings.UntilAttribute, recipe.startTime + recipe.curve.duration)

	drives[victim] = {
		root = root,
		humanoid = humanoid,
		recipe = recipe,
		isOwner = isOwner,
		autoRotate = autoRotate,
		startRotation = startRotation,
		targetRotation = targetRotation,
		finishedAt = nil,
		lastAlpha = 0,
		lastAt = now(),
	}

	if not connection then
		local signal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
		connection = signal:Connect(step)
	end

	return true
end

function KnockbackService.Cancel(victim)
	active[victim] = nil

	local drive = drives[victim]
	if drive then
		finish(victim, drive)
	end
end

return KnockbackService
