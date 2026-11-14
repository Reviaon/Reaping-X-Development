-- Runs on whichever machine simulates a rig: the server for NPCs, the owning client for its own
-- character. Toggles are queued and applied in PreSimulation so the joint switch and any root
-- move land in the same physics step, never between a step and a render.

local RunService = game:GetService("RunService")

local Profiles = require(script.Parent.Profiles)
local Codec = require(script.Parent.Codec)

local Simulator = {}

local IS_SERVER = RunService:IsServer()

Simulator.SEND_RATE = 20
Simulator.BLEND_OUT = 0.3
Simulator.TAIL = 0.5
Simulator.PIN_INTERVAL = 0.25
-- Soft limits never touch AngularStrength. Switching stiffness by angle chatters as soon as gravity
-- holds a joint in the zone (stiffer lifts it out, softer drops it back: 55 writes in 2 s, the head
-- never settled), and on the server every write replicates. Instead the muscle's target is pushed
-- away from the limit by an amount that grows with depth: a continuous nonlinear spring, written
-- through Transform, which does not replicate. Kept gentle because it only updates once a frame.
local MAX_SOFT_SHIFT = math.rad(60)
local CORE_PARTS = { HumanoidRootPart = true, Torso = true, Head = true }
-- A launch faster than this when the ragdoll starts (any source: knockback, a LinearVelocity) is
-- treated as a hit on the torso, so limbs lag the same way as with Fling.
local ENTRY_STRIKE_SPEED = 30
-- After a hit the muscles drop to RELAX_MIN of their strength and recover over RELAX_TIME, in
-- RELAX_STEPS writes (on the server AngularStrength replicates, so not every frame). Damping is a
-- ratio of strength, so this is also what lets limbs whip: at full strength a limb's swing
-- relative to the torso dies in ~60 ms.
local RELAX_MIN = 0.1
local RELAX_TIME = 0.6
local RELAX_STEPS = 8
-- Where on the Torso a Fling lands when no point is given, in its half-heights above centre.
local DEFAULT_HIT_HEIGHT = 0.6

-- Set by init: called with (rig, flags) whenever the pose should go on the stream.
Simulator.onSample = nil :: ((any, number) -> ())?
-- Set by init: who the server pins a split rig's parts to (nil = server).
Simulator.ownerOf = function(_rig): Player?
	return nil
end

local states: { [Model]: any } = {}

local function setRigid(rig, rigid: boolean)
	for _, j in rig.joints do
		j.motor.Enabled = rigid
	end
end
Simulator.setRigid = setRigid

local function pin(rig, owner: Player?)
	for _, part in rig.model:GetChildren() do
		if part:IsA("BasePart") and not part.Anchored then
			local ok, can = pcall(part.CanSetNetworkOwnership, part)
			if ok and can then
				pcall(part.SetNetworkOwner, part, owner)
			end
		end
	end
end
Simulator.pin = pin

local function relative(j): CFrame
	return (j.part0.CFrame * j.c0):Inverse() * (j.part1.CFrame * j.c1)
end
Simulator.relative = relative

local function loadProfile(state)
	local rig = state.rig
	local model = rig.model
	local profile = Profiles.get(model:GetAttribute("RagdollProfile"))
	local strengthScale = model:GetAttribute("RagdollStrengthScale") or 1
	local softScale = model:GetAttribute("RagdollSoftScale") or 1
	state.profile = profile
	local air = profile.air
	state.air = air and {
		lift = 1 - (model:GetAttribute("RagdollGravityScale") or air.gravity),
		drag = air.drag * (model:GetAttribute("RagdollDragScale") or 1),
		limbDrag = air.limbDrag,
	}
	for _, j in rig.joints do
		local spec = Profiles.spec(profile, j.name)
		local l0, l1 = j.socket.Attachment0.CFrame, j.socket.Attachment1.CFrame
		-- Limit frame relative to the muscle frame (a0), not the motor's C0: on R6 they differ.
		local f0 = (j.a0.CFrame:Inverse() * l0).Rotation
		local gain = (spec.softGain or 0) * softScale
		j.sim = {
			neutral = Profiles.neutral(spec, j.name),
			drive = (spec.strength or 0) * strengthScale > 0,
			l0 = l0,
			l1 = l1,
			f0 = f0,
			f0inv = f0:Inverse(),
			cone = spec.cone or 0,
			lo = spec.twist and spec.twist[1] or 0,
			hi = spec.twist and spec.twist[2] or 0,
			softCone = spec.softCone or 0,
			softTwist = spec.softTwist or 0,
			gain = if gain > 0 then gain else nil,
			strength = (spec.strength or 0) * strengthScale,
		}
	end
end

-- Pull-back rotation (in the limit frame, applied to the child) for a joint inside its soft zone,
-- or nil. Swing is the tilt of the child's X from the parent's; twist is rotation about it.
local function softCorrection(sim, r: CFrame): CFrame?
	local q: CFrame? = nil
	local x1 = r.XVector
	if sim.softCone > 0 then
		local swing = math.deg(math.acos(math.clamp(x1.X, -1, 1)))
		local start = sim.cone - sim.softCone
		if swing > start then
			local e = math.min(swing - start, sim.softCone)
			local axis = Vector3.new(0, -x1.Z, x1.Y)
			if axis.Magnitude > 1e-4 then
				local c = math.min(math.rad(sim.gain * e * e / sim.softCone), MAX_SOFT_SHIFT)
				q = CFrame.fromAxisAngle(axis.Unit, -c)
			end
		end
	end
	if sim.softTwist > 0 then
		local _, _, _, m00, _, _, _, m11, m12, _, m21, m22 = r:GetComponents()
		local w = math.sqrt(math.max(0, 1 + m00 + m11 + m22)) * 0.5
		if w > 1e-4 then
			local twist = math.deg(2 * math.atan2((m21 - m12) / (4 * w), w))
			local e = 0
			if twist > sim.hi - sim.softTwist then
				e = math.min(twist - (sim.hi - sim.softTwist), sim.softTwist)
			elseif twist < sim.lo + sim.softTwist then
				e = -math.min((sim.lo + sim.softTwist) - twist, sim.softTwist)
			end
			if e ~= 0 then
				local c = math.min(math.rad(sim.gain * e * e / sim.softTwist), MAX_SOFT_SHIFT) * math.sign(e)
				local t = CFrame.fromAxisAngle(x1, -c)
				q = if q then t * q else t
			end
		end
	end
	return q
end

-- Muscle target for this frame: the neutral pose, pushed back from any limit the joint is in the
-- soft zone of. Limit frame R = F0^-1 * T * F1, so a pull-back Q on R is (F0 Q F0^-1) on T.
local function muscleTarget(j): CFrame
	local sim = j.sim
	if not sim.gain then
		return sim.neutral
	end
	local r = (j.part0.CFrame * sim.l0):ToObjectSpace(j.part1.CFrame * sim.l1)
	local q = softCorrection(sim, r)
	if not q then
		return sim.neutral
	end
	return sim.f0 * q * sim.f0inv * sim.neutral
end

-- Per-frame impulses on every free part: lift cancels part of gravity evenly (uniform, so it does
-- not bend the pose), drag pulls each part against its own velocity, more on limbs so they trail.
-- ApplyImpulse instead of a VectorForce: nothing replicates.
local function applyAir(state, dt: number)
	local air = state.air
	if not air or state.rig.torso:IsGrounded() then
		return
	end
	local lift = Vector3.new(0, workspace.Gravity * air.lift * dt, 0)
	for _, part in state.parts do
		if not part.Parent or part:IsGrounded() then
			continue
		end
		local mass = part:GetMass()
		local v = part:GetVelocityAtPosition(part.Position)
		local speed = v.Magnitude
		local dv = lift
		if speed > 1e-3 and air.drag > 0 then
			local k = if CORE_PARTS[part.Name] then air.drag else air.drag * air.limbDrag
			dv -= v * (math.min(k * speed * dt, 1))
		end
		part:ApplyImpulseAtPosition(dv * mass, part.Position)
	end
end

local function setRelax(state, factor: number)
	for _, j in state.rig.joints do
		if j.sim and j.sim.drive then
			j.muscle.AngularStrength = j.sim.strength * factor
		end
	end
end

local function relaxStep(state, now: number)
	local t = (now - state.relaxStart) / RELAX_TIME
	if t >= 1 then
		setRelax(state, 1)
		state.relaxStart = nil
		state.relaxStep = nil
		return
	end
	local step = math.floor(t * RELAX_STEPS)
	if step ~= state.relaxStep then
		state.relaxStep = step
		local a = (step + 1) / RELAX_STEPS
		setRelax(state, RELAX_MIN + (1 - RELAX_MIN) * a * a)
	end
end

-- The joints toggle a frame late; until then the whole rig is one assembly and an impulse on the
-- torso would move every limb with it.
local function isSplit(rig): boolean
	local torsoRoot = rig.torso.AssemblyRootPart
	for _, j in rig.joints do
		if j.part1.AssemblyRootPart ~= torsoRoot then
			return true
		end
	end
	return false
end

-- A hit on the torso: `coreImpulse` goes into the torso assembly at `at` (an off-centre hit spins
-- the body), every limb assembly changes velocity by `limbDv`, and the joints do the rest: limbs
-- trail, the body tips. Returns false while the joints have not split into separate assemblies
-- yet, so the caller retries.
local function strike(state, coreImpulse: Vector3, limbDv: Vector3, at: Vector3?): boolean
	local rig = state.rig
	local torso = rig.torso
	if not torso.Parent or torso:IsGrounded() then
		return true
	end
	if not isSplit(rig) then
		return false
	end
	local torsoRoot = torso.AssemblyRootPart

	local hit = at or (torso.Position + torso.CFrame.UpVector * (torso.Size.Y * 0.5 * DEFAULT_HIT_HEIGHT))
	torso:ApplyImpulseAtPosition(coreImpulse, hit)

	if limbDv.Magnitude > 0 then
		for _, part in state.parts do
			if part.Parent and part.AssemblyRootPart == part and part ~= torsoRoot and not part:IsGrounded() then
				part:ApplyImpulse(limbDv * part.AssemblyMass)
			end
		end
	end

	state.relaxStart = os.clock()
	state.relaxStep = nil
	return true
end

-- Free assemblies' total mass, momentum, and the limbs' share of the mass.
local function bodyMomentum(state, torsoRoot: BasePart): (number, Vector3, number)
	local mass, momentum, limbMass = 0, Vector3.zero, 0
	for _, part in state.parts do
		if part.Parent and part.AssemblyRootPart == part and not part:IsGrounded() then
			local m = part.AssemblyMass
			mass += m
			momentum += part.AssemblyLinearVelocity * m
			if part ~= torsoRoot then
				limbMass += m
			end
		end
	end
	return mass, momentum, limbMass
end

-- Fling: bring the body's centre of mass to `velocity` with one impulse on the torso.
local function applyFling(state, fling): boolean
	local rig = state.rig
	if not isSplit(rig) then
		return false
	end
	local mass, momentum, limbMass = bodyMomentum(state, rig.torso.AssemblyRootPart)
	if mass <= 0 then
		return true
	end
	if fling.limbLag then
		-- Entry strike: the body already moves at the launch speed as one piece. Take the limbs'
		-- share of it away and hand it to the torso, total momentum unchanged.
		return strike(state, fling.limbLag * limbMass, -fling.limbLag, fling.at)
	end
	local struck = strike(state, fling.velocity * mass - momentum, Vector3.zero, fling.at)
	if struck and fling.spin then
		rig.torso.AssemblyAngularVelocity = fling.spin
	end
	return struck
end

local function enter(state)
	local rig = state.rig
	local humanoid, root = rig.humanoid, rig.root
	loadProfile(state)
	local profile = state.profile

	local saved = {}
	local parts = {}
	for _, part in rig.parts do
		if part.Parent == rig.model then
			table.insert(parts, part)
			saved[part] = { CanCollide = part.CanCollide, Massless = part.Massless, Physical = part.CustomPhysicalProperties }
			if part == root then
				part.CanCollide = false
				-- Near-weightless rather than Massless: a Massless part loses the root election
				-- whatever its RootPriority, so the torso assembly would root at the Torso here
				-- and at the root everywhere else, and the owner's physics would be dropped.
				if profile.fixMass then
					part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 1, 1)
				end
			else
				if profile.collideLimbs then
					part.CanCollide = true
				end
				if profile.fixMass then
					part.Massless = false
				end
			end
		end
	end
	state.saved = saved
	state.parts = parts

	-- An anchored root that carries a velocity drags every muscle and socket attached to it
	-- forever (their damping and friction act on relative motion), and the ragdoll explodes.
	if root.Anchored then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- The stream's first sample is the pose at the moment of the switch, so observers take over
	-- from exactly what they were already showing.
	if Simulator.onSample then
		Simulator.onSample(rig, Codec.RAGDOLLED)
	end

	-- Whatever launched the rig, its limbs should lag the torso. Only the horizontal and upward
	-- part counts: a fall should not leave the legs hanging up in the air.
	if not state.fling and not root.Anchored then
		local v = root.AssemblyLinearVelocity
		local launch = Vector3.new(v.X, math.max(v.Y, 0), v.Z)
		if launch.Magnitude >= ENTRY_STRIKE_SPEED then
			state.fling = { limbLag = launch, tries = 0 }
		end
	end

	setRigid(rig, false)
	state.ragdolled = true
	state.blend = nil
	state.tailUntil = nil
	state.nextSend = os.clock() + 1 / Simulator.SEND_RATE
	if IS_SERVER then
		local owner = Simulator.ownerOf(rig)
		pin(rig, owner)
		state.owner = owner
		state.nextPin = os.clock() + 0.05
	end
end

local function flatYaw(v: Vector3): Vector3?
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.3 then
		return nil
	end
	return flat.Unit
end

local function exit(state)
	local rig = state.rig
	local model, humanoid, root = rig.model, rig.humanoid, rig.root
	local rootJoint = rig.rootJoint

	local from = {}
	for _, j in rig.all do
		from[j] = relative(j)
	end

	local newRoot: CFrame? = nil
	if not root.Anchored and rootJoint and model:GetAttribute("RagdollUprightOnExit") ~= false then
		local pelvis = rootJoint.part1.CFrame
		local look = flatYaw(pelvis.LookVector) or flatYaw(pelvis.UpVector) or flatYaw(root.CFrame.LookVector) or Vector3.zAxis
		newRoot = CFrame.lookAlong(pelvis.Position, look) * (rootJoint.c1 * rootJoint.c0:Inverse())
		from[rootJoint] = (newRoot * rootJoint.c0):Inverse() * (pelvis * rootJoint.c1)
	end

	setRigid(rig, true)
	for _, j in rig.all do
		j.motor.Transform = from[j]
	end
	if newRoot then
		root.CFrame = newRoot
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	for part, props in state.saved or {} do
		if part.Parent then
			part.CanCollide = props.CanCollide
			part.Massless = props.Massless
			part.CustomPhysicalProperties = props.Physical
		end
	end
	state.saved = nil
	if state.relaxStart then
		setRelax(state, 1)
		state.relaxStart = nil
	end
	state.parts = nil
	state.fling = nil

	if humanoid.Health > 0 then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	state.ragdolled = false
	state.blend = { from = from, start = os.clock() }
	state.tailUntil = os.clock() + Simulator.BLEND_OUT + Simulator.TAIL
	if IS_SERVER and state.owner ~= nil then
		state.owner = nil
	end
end

local function preAnimation()
	for _, state in states do
		if state.blend then
			for _, j in state.rig.all do
				j.motor.Transform = CFrame.identity
			end
		end
	end
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function preSimulation(dt: number)
	local now = os.clock()
	for model, state in states do
		local rig = state.rig
		if not model.Parent then
			states[model] = nil
			continue
		end

		if state.want ~= nil and state.want ~= state.ragdolled then
			if state.want then
				enter(state)
			else
				exit(state)
			end
		end
		state.want = nil

		if state.ragdolled then
			for _, j in rig.joints do
				if j.sim and j.sim.drive then
					j.muscle.Transform = muscleTarget(j)
				end
			end
			if rig.rootJoint then
				rig.rootJoint.motor.Transform = CFrame.identity
			end
			local fling = state.fling
			if fling then
				fling.tries += 1
				if applyFling(state, fling) or fling.tries > 5 then
					state.fling = nil
				end
			end
			applyAir(state, dt)
			if state.relaxStart then
				relaxStep(state, now)
			end
			if IS_SERVER and state.nextPin and now >= state.nextPin then
				state.nextPin = now + Simulator.PIN_INTERVAL
				pin(rig, state.owner)
			end
		elseif state.blend then
			local a = (now - state.blend.start) / Simulator.BLEND_OUT
			if a >= 1 then
				state.blend = nil
			else
				a = smooth(a)
				for _, j in rig.all do
					j.motor.Transform = state.blend.from[j]:Lerp(j.motor.Transform, a)
				end
			end
		end

		local streaming = state.ragdolled or (state.tailUntil and now < state.tailUntil)
		if streaming and Simulator.onSample and now >= state.nextSend then
			state.nextSend = now + 1 / Simulator.SEND_RATE
			Simulator.onSample(rig, if state.ragdolled then Codec.RAGDOLLED else 0)
		elseif not state.ragdolled and state.tailUntil and now >= state.tailUntil then
			state.tailUntil = nil
			if Simulator.onSample then
				Simulator.onSample(rig, Codec.FINAL)
			end
		end

		if not state.ragdolled and not state.blend and not state.tailUntil then
			states[model] = nil
		end
	end
end

function Simulator.set(rig, enabled: boolean)
	local state = states[rig.model]
	if not state then
		if not enabled then
			return
		end
		state = { rig = rig, ragdolled = false }
		states[rig.model] = state
	end
	state.want = enabled
end

-- Queues a launch for the next physics step. Only works on the machine simulating the rig, after
-- it has been asked to ragdoll (applied once the ragdoll is entered). Returns false otherwise.
function Simulator.fling(model: Model, velocity: Vector3, at: Vector3?, spin: Vector3?): boolean
	local state = states[model]
	if not state then
		return false
	end
	state.fling = { velocity = velocity, at = at, spin = spin, tries = 0 }
	return true
end

function Simulator.isRagdolled(model: Model): boolean
	local state = states[model]
	return state ~= nil and state.ragdolled == true
end

function Simulator.reloadProfile(model: Model)
	local state = states[model]
	if state and state.ragdolled then
		loadProfile(state)
	end
end

function Simulator.start()
	RunService.PreAnimation:Connect(preAnimation)
	RunService.PreSimulation:Connect(preSimulation)
end

return Simulator
