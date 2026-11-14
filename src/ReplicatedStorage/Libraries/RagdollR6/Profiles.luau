-- R6 joint profiles. Angles in degrees.
--
-- R6 Motor6D frames are rotated (a limb motor hinges about its Z), so Rig builds its own joint
-- frames at the motor pivots with the Torso's axes: X = the body's right side, Y = up, Z = back.
-- Everything below lives in those frames, which match the R15 module's: `twist` is flexion
-- (positive swings a downward bone forward and the head backward), `cone` bounds how far X may tip.
-- Shoulders use Roblox's avatar frames (cone centred on "arm out sideways", twist about the arm).
--
-- R6 limbs are single pieces, so the hips and shoulders carry the whole limb's range.
--
-- `neutral` is the relaxed pose the muscles pull toward, in joint-frame space:
-- flex about X, twist about Y, abd about Z (mirrored for Left joints).
--
-- strength is AnimationConstraint.AngularStrength (natural frequency / 60 Hz, mass-normalised),
-- damping the damping ratio. The soft zone is the last `softCone` / `softTwist` degrees before
-- each hard limit; inside it the muscle's target is pushed back by softGain * depth^2 / width.

local DEG = math.rad

local Profiles = {}

local SHOULDER_FRAMES = {
	["Right Shoulder"] = { CFrame.identity, CFrame.fromOrientation(0, 0, DEG(-90)) },
	["Left Shoulder"] = { CFrame.fromOrientation(0, DEG(180), 0), CFrame.fromOrientation(0, DEG(-180), DEG(-90)) },
}

local AIR = { gravity = 0.55, drag = 0.004, limbDrag = 1.8 }

-- Roblox's R15 avatar-joint limits on the joints R6 has. Legs and arms are one piece here, so the
-- hip gets the knee's backward room it would otherwise lack.
Profiles.Hard = {
	frames = SHOULDER_FRAMES,
	collideLimbs = true,
	fixMass = true,
	air = AIR,
	joints = {
		Hip = { cone = 40, twist = { -20, 80 }, friction = 22 },
		Shoulder = { cone = 110, twist = { -85, 85 }, friction = 33 },
		Neck = { cone = 45, twist = { -40, 40 }, friction = 43 },
		Default = { cone = 20, twist = { -15, 15 }, friction = 20 },
	},
}

Profiles.Soft = {
	frames = SHOULDER_FRAMES,
	collideLimbs = true,
	fixMass = true,
	air = AIR,
	joints = {
		Hip = {
			cone = 40, twist = { -25, 100 }, friction = 2,
			strength = 0.03, damping = 0.7, softGain = 1.5, softCone = 15, softTwist = 18,
			neutral = { flex = 10, abd = 4 },
		},
		Shoulder = {
			cone = 110, twist = { -85, 85 }, friction = 2,
			strength = 0.025, damping = 0.7, softGain = 1.5, softCone = 20, softTwist = 25,
			neutral = { flex = 12, abd = 10 },
		},
		Neck = {
			cone = 45, twist = { -40, 40 }, friction = 2,
			strength = 0.05, damping = 0.8, softGain = 1.5, softCone = 12, softTwist = 15,
			neutral = { flex = -10 },
		},
		Default = {
			cone = 20, twist = { -15, 15 }, friction = 2,
			strength = 0.03, damping = 0.7, softGain = 1.5, softCone = 6, softTwist = 6,
		},
	},
}

Profiles.Default = "Soft"

local TYPES = { "Shoulder", "Hip", "Neck" }

function Profiles.jointType(jointName: string): string
	for _, t in TYPES do
		if string.sub(jointName, -#t) == t then
			return t
		end
	end
	return "Default"
end

function Profiles.get(name: string?)
	local profile = Profiles[name or Profiles.Default]
	if type(profile) ~= "table" or not profile.joints then
		profile = Profiles[Profiles.Default]
	end
	return profile
end

function Profiles.spec(profile, jointName: string)
	local joints = profile.joints
	return joints[Profiles.jointType(jointName)] or joints.Default
end

function Profiles.neutral(spec, jointName: string): CFrame
	local n = spec.neutral
	if not n then
		return CFrame.identity
	end
	local mirror = if string.sub(jointName, 1, 4) == "Left" then -1 else 1
	return CFrame.Angles(DEG(n.flex or 0), DEG((n.twist or 0) * mirror), DEG((n.abd or 0) * mirror))
end

function Profiles.frames(profile, jointName: string): (CFrame, CFrame)
	local f = profile.frames[jointName]
	if f then
		return f[1], f[2]
	end
	return CFrame.identity, CFrame.identity
end

return Profiles
