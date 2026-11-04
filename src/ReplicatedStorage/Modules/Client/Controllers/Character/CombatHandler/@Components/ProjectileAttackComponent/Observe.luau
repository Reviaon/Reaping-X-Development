local Config = require("./Config")
local Weapon = require("./Weapon")
local Aim = require("./Aim")
local Nock = require("./Nock")

local Observe = {}

local views = setmetatable({}, { __mode = "k" })
local clipLengths = {}

local function clipLength(controller, id: string, projectile, phase: string): number
	local key = Config.ClipKey[phase]
	if not key or not controller.Character then return math.huge end

	local name = Weapon.AnimationName(id, projectile, key)

	if not clipLengths[name] then
		local ok, track = pcall(controller.AnimatorService.GetTrack, controller.AnimatorService, controller.Character, name)
		local length = ok and track and track.Length or 0

		if length <= 0 then return Config.FallbackLength end

		clipLengths[name] = length
	end

	return clipLengths[name]
end

function Observe.Step(controller, dt: number)
	local world = workspace:FindFirstChild("World")
	local living = world and world:FindFirstChild("Live")
	local config = controller.CombatConfig
	if not living or not config then return end

	for _, character in living:GetChildren() do
		if character == controller.Character then continue end

		local phase = character:GetAttribute("ProjectileState")
		local id = character:GetAttribute("EquippedWeapon")
		local data = typeof(phase) == "string" and typeof(id) == "string" and config.WeaponConfig[id]
		local projectile = data and data.projectile
		local view = views[character]

		if not projectile then
			if view and view.armSettings and (view.armPitch or 0) ~= 0 then
				Aim.PitchArms(character, view, view.armSettings, 0, dt)
			end

			continue
		end

		if not view then
			view = {}
			views[character] = view
		end

		local pitch = character:GetAttribute("ProjectilePitch")
		Aim.PitchArms(character, view, projectile.arm_pitch, if typeof(pitch) == "number" then math.rad(pitch) else 0, dt)

		local at = character:GetAttribute("ProjectileStateAt") or 0

		if view.at ~= at or view.phase ~= phase then
			view.at = at
			view.phase = phase
			view.phaseStart = os.clock() - math.max(0, workspace:GetServerTimeNow() - at)
			view.clipLength = clipLength(controller, id, projectile, phase)
		end

		view.nocked = character:GetAttribute("ProjectileNocked") == true
		view.released = phase == "Firing"

		Nock.Update(character, view, projectile)
	end
end

return Observe
