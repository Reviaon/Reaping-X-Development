local Motion = {}

Motion.Settings = {
	StopSpeed = 0.25,
	SpeedEpsilon = 0.05,
	TurnSlowdown = 0.2,
	MinTurnFactor = 0.05,
	HeadingEpsilon = 0.01,
	ArriveDistance = 1.5,
	HeadingTolerance = 0.99995,
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function approach(current: number, target: number, rise: number, fall: number, dt: number): number
	if target > current then
		return math.min(target, current + rise * dt)
	end

	return math.max(target, current - fall * dt)
end

local function turnFactor(look: Vector3, direction: Vector3): number
	local settings = Motion.Settings

	if look.Magnitude <= 0 or direction.Magnitude <= 0 then return 1 end

	local alignment = look.Unit:Dot(direction.Unit)

	return math.clamp((alignment + settings.TurnSlowdown) / (1 + settings.TurnSlowdown), settings.MinTurnFactor, 1)
end

local function arrivalCap(mob): number
	local deceleration = mob.Config.deceleration
	if not deceleration or not mob.Moving or mob.Stopping or not mob.Destination then return math.huge end
	if mob.FreeUntil and os.clock() < mob.FreeUntil then return math.huge end

	local remaining = flat(mob.Destination - mob.Root.Position).Magnitude - Motion.Settings.ArriveDistance

	return math.sqrt(2 * deceleration * math.max(remaining, 0))
end

local function updateSpeed(mob, heading: Vector3?, dt: number)
	local settings = Motion.Settings
	local config = mob.Config
	local humanoid = mob.Humanoid
	local desired = math.min(mob.DesiredSpeed, arrivalCap(mob))

	if desired > 0 and heading then
		desired *= turnFactor(flat(mob.Root.CFrame.LookVector), heading)
	end

	mob.Speed = approach(mob.Speed, desired, config.acceleration or math.huge, config.deceleration or math.huge, dt)

	if math.abs(humanoid.WalkSpeed - mob.Speed) > settings.SpeedEpsilon then
		humanoid.WalkSpeed = mob.Speed
	end

	if mob.Stopping and mob.Speed <= settings.StopSpeed then
		mob.Stopping = false
		mob.Moving = false
		humanoid:MoveTo(mob.Root.Position)
	end
end

local function headingOf(mob): Vector3?
	local settings = Motion.Settings
	local origin = mob.Root.Position

	if mob.FacePoint then
		local heading = flat(mob.FacePoint - origin)
		return if heading.Magnitude > settings.HeadingEpsilon then heading.Unit else nil
	end

	if not mob.Moving or mob.Stopping or mob.Nudging or not mob.Destination then return nil end

	local heading = flat(mob.Destination - origin)

	return if heading.Magnitude > settings.ArriveDistance then heading.Unit else nil
end

local function updateHeading(mob, heading: Vector3?)
	local facing = mob.Facing
	if not facing or not heading then return end

	local written = mob.WrittenHeading

	if written and written:Dot(heading) >= Motion.Settings.HeadingTolerance and facing.Enabled then return end

	mob.WrittenHeading = heading
	facing.CFrame = CFrame.lookAt(Vector3.zero, heading)

	if not facing.Enabled then
		facing.Enabled = true
	end
end

function Motion.Step(mob, dt: number)
	if mob.Halted then return end

	local heading = headingOf(mob)

	updateSpeed(mob, heading, dt)
	updateHeading(mob, heading)
end

return Motion
