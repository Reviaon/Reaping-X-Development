local Config = require("./Config")
local Types = require("./Types")

type Session = Types.Session

local Locomotion = {}

local REFERENCE: { [string]: string } = {
	Walk = "walk_speed",
	WalkLeft = "walk_speed",
	WalkRight = "walk_speed",
	WalkBack = "walk_speed",
	Run = "run_speed",
}

local function forwardKey(session: Session, speed: number, current: string?): string
	local midpoint = (session.WalkSpeed + session.RunSpeed) / 2
	local margin = if current == "Run" then -Config.RunHysteresis else Config.RunHysteresis

	return if speed >= midpoint + margin then "Run" else "Walk"
end

local function keyFor(session: Session, planar: Vector3, current: string?): string
	local speed = planar.Magnitude
	if speed < Config.IdleThreshold then return "Idle" end

	local relative = session.Root.CFrame:VectorToObjectSpace(planar)
	local forward, side = -relative.Z, relative.X
	local key

	if forward >= math.abs(side) then
		key = forwardKey(session, speed, current)
	elseif -forward >= math.abs(side) then
		key = "WalkBack"
	else
		key = if side > 0 then "WalkRight" else "WalkLeft"
	end

	return if session.Profile.animations[key] then key else "Walk"
end

local function partnersOf(session: Session, key: string): { string }
	local partners = {}

	for _, pair in session.Profile.exclusive do
		if pair[1] == key then
			table.insert(partners, pair[2])
		elseif pair[2] == key then
			table.insert(partners, pair[1])
		end
	end

	return partners
end

local function blocked(session: Session, key: string, now: number): boolean
	local clearAt = session.State.ClearAt
	local held = false

	for _, partner in partnersOf(session, key) do
		local until_ = clearAt[partner] or 0

		if session.Animator:Playing(partner) then
			session.Animator:Stop(partner, Config.ExclusiveFade)
			until_ = now + Config.ExclusiveFade
			clearAt[partner] = until_
		end

		if until_ > now then
			held = true
		end
	end

	return held
end

local function playback(session: Session, key: string, speed: number): number
	local field = REFERENCE[key]
	local reference = if field == "walk_speed" then session.Profile.walk_speed elseif field == "run_speed" then session.Profile.run_speed else nil
	if not reference or reference <= 0 then return 1 end

	local scale = session.Profile.animation_speeds[key] or 1

	return math.clamp(speed / reference, Config.PlaybackRange[1], Config.PlaybackRange[2]) * scale
end

function Locomotion.Step(session: Session)
	local state = session.State
	local velocity = session.Root.AssemblyLinearVelocity
	local planar = Vector3.new(velocity.X, 0, velocity.Z)
	local key = keyFor(session, planar, state.Locomotion)
	local now = os.clock()

	if key ~= state.Locomotion then
		if state.Locomotion then
			session.Animator:Stop(state.Locomotion, Config.LocomotionFade)
			state.ClearAt[state.Locomotion] = now + Config.LocomotionFade
			state.Locomotion = nil
		end

		if blocked(session, key, now) then return end

		state.Locomotion = key
		session.Animator:Loop(key, if key == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement)
	end

	local track = session.Animator:Playing(key)
	if not track then return end

	local speed = playback(session, key, planar.Magnitude)

	if math.abs(track.Speed - speed) > Config.PlaybackEpsilon then
		track:AdjustSpeed(speed)
	end
end

return Locomotion
