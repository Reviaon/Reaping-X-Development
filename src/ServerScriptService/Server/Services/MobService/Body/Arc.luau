local Rig = require("./Rig")

local Arc = {}

Arc.Settings = {
	ProbeUp = 6,
	ProbeDown = 30,
	DefaultHome = 14,
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function groundRootY(mob, position: Vector3, fallback: number): number
	local settings = Arc.Settings
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live") or mob.Model }
	params.RespectCanCollide = true

	local hit = workspace:Raycast(position + Vector3.yAxis * settings.ProbeUp, Vector3.yAxis * -(settings.ProbeUp + settings.ProbeDown), params)
	if not hit then return fallback end

	return hit.Position.Y + (mob.Model:GetAttribute(Rig.Settings.RootHeightAttribute) or 0)
end

function Arc.Begin(mob, landing: Vector3, duration: number, height: number, options: { Home: number?, Aim: (() -> Vector3?)?, OnStep: ((number) -> ())?, OnLand: (() -> ())?, Airborne: boolean?, Hold: boolean? }?)
	local root = mob.Root
	local start = root.Position

	mob:Halt()

	mob.Arc = {
		Start = start,
		Landing = if options and options.Airborne then landing else Vector3.new(landing.X, groundRootY(mob, landing, start.Y), landing.Z),
		Hold = options and options.Hold == true,
		Landed = false,
		Duration = math.max(duration, 1e-3),
		Height = height,
		Home = options and options.Home or Arc.Settings.DefaultHome,
		Aim = options and options.Aim,
		OnStep = options and options.OnStep,
		OnLand = options and options.OnLand,
		At = os.clock(),
	}
end

function Arc.Active(mob): boolean
	return mob.Arc ~= nil
end

local function land(arc)
	if arc.Landed then return end

	arc.Landed = true

	if arc.OnLand then
		arc.OnLand()
	end
end

function Arc.Remaining(mob): number
	local arc = mob.Arc
	return if arc then math.max(arc.At + arc.Duration - os.clock(), 0) else 0
end

function Arc.Stop(mob)
	local arc = mob.Arc
	if not arc then return end

	mob.Arc = nil
	land(arc)

	mob.Root.AssemblyLinearVelocity = Vector3.zero
	mob:Resume()
end

function Arc.Step(mob, dt: number): boolean
	local arc = mob.Arc
	if not arc then return false end

	local root = mob.Root

	if arc.Landed then
		root.CFrame = CFrame.lookAt(arc.Landing, arc.Landing + flat(root.CFrame.LookVector))
		root.AssemblyLinearVelocity = Vector3.zero
		return true
	end

	local wanted = arc.Aim and arc.Aim()

	if wanted then
		local goal = Vector3.new(wanted.X, arc.Landing.Y, wanted.Z)
		local shift = goal - arc.Landing
		local limit = arc.Home * dt

		if shift.Magnitude > limit then
			shift = shift.Unit * limit
		end

		arc.Landing += shift
	end

	local s = math.clamp((os.clock() - arc.At) / arc.Duration, 0, 1)
	local across = arc.Start:Lerp(arc.Landing, s)
	local position = across + Vector3.yAxis * (4 * arc.Height * s * (1 - s))
	local travel = flat(arc.Landing - arc.Start)
	local look = if travel.Magnitude > 1e-3 then travel.Unit else flat(root.CFrame.LookVector).Unit
	local rise = 4 * arc.Height * (1 - 2 * s) / arc.Duration

	root.CFrame = CFrame.lookAt(position, position + look)
	root.AssemblyLinearVelocity = (arc.Landing - arc.Start) / arc.Duration + Vector3.yAxis * rise

	if arc.OnStep then
		arc.OnStep(s)
	end

	if s >= 1 then
		if arc.Hold then
			land(arc)
		else
			Arc.Stop(mob)
		end
	end

	return true
end

return Arc
