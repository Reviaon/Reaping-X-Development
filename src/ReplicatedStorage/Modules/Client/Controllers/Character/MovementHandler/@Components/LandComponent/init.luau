--@ Landing
local Jloader = require("@game/ReplicatedStorage/JLoader")
local Config = require("@self/Config")
local PropertiesConfig = require("@game/ReplicatedStorage/Modules/Client/Controllers/Character/PropertiesHandler/Config")

local LandComponent = {}

local SCOPE = "Land"

local AIRBORNE = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local GROUNDED = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function minAirtime(): number
	return 2 * PropertiesConfig.Jump.MinPower / workspace.Gravity * Config.MinJumpShare
end

local function release(state)
	if state.fadeThread then
		task.cancel(state.fadeThread)
		state.fadeThread = nil
	end

	if state.moveWatch then
		state.moveWatch:Disconnect()
		state.moveWatch = nil
	end
end

local function fadeOut(state, track: AnimationTrack, fade: number)
	if state.track ~= track then return end

	state.fadeThread = nil
	release(state)
	state.track = nil
	track:Stop(fade)
end

local function blendFor(controller)
	local sprinting = controller.StatusService:CheckStatuses(controller.Character, { [Config.SprintStatus] = true })

	return sprinting and Config.Sprinting or Config.Walking
end

local function land(controller, state, airtime: number)
	local character = controller.Character
	local humanoid = controller.Humanoid

	if controller.StatusService:CheckStatuses(character, Config.SkipStatuses) then return end

	local landing = airtime >= Config.HeavyAirtime and Config.Heavy or Config.Light

	if not controller.AnimatorService:HasAnimation(landing.Animation) then return end

	release(state)

	if state.track then
		state.track:Stop(Config.FadeTime)
	end

	local rooted = landing.Status ~= nil
	local blend = not rooted and humanoid.MoveDirection.Magnitude > 0 and blendFor(controller) or nil

	local track = controller.AnimatorService:PlayTrack(character, landing.Animation, {
		Speed = landing.Speed,
		Weight = blend and blend.Weight or 1,
		Priority = landing.Priority,
		FadeTime = Config.FadeTime,
		Loop = false,
	})

	state.track = track

	local camera = landing.Shake and Jloader.GetHandler("CameraHandler")

	if camera then
		camera:Shake(landing.Shake)
	end

	local length = track.Length / landing.Speed

	if rooted then
		controller.StatusService:SetStatus(character, landing.Status, true, length > 0 and length or landing.StatusFallback)
	end

	if blend then
		state.fadeThread = task.delay(blend.Hold, fadeOut, state, track, blend.Fade)
		return
	end

	if length > 0 then
		state.fadeThread = task.delay(math.max(length - Config.FadeOut, 0), fadeOut, state, track, Config.FadeOut)
	end

	if not rooted then
		state.moveWatch = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0 then
				fadeOut(state, track, blendFor(controller).Fade)
			end
		end)
	end
end

function LandComponent:Init(controller)
	if not controller.Character then return end

	LandComponent.Reset(controller)

	local state = controller:Scope(SCOPE)

	state.trove = controller.Trove.new()

	state.trove:Add(controller.Humanoid.StateChanged:Connect(function(_, new)
		if AIRBORNE[new] then
			state.airborneSince = state.airborneSince or os.clock()
			return
		end

		local since = state.airborneSince
		state.airborneSince = nil

		if not since or not GROUNDED[new] then return end

		local airtime = os.clock() - since

		if airtime >= minAirtime() then
			land(controller, state, math.min(airtime, Config.MaxAirtime))
		end
	end))

	state.trove:Add(controller.Humanoid.Died:Connect(function()
		LandComponent.Reset(controller)
	end))
end

function LandComponent.Reset(controller)
	if not controller then return end

	local state = controller:Scope(SCOPE)

	release(state)

	state.airborneSince = nil
	state.track = nil

	if state.trove then
		state.trove:Clean()
		state.trove = nil
	end
end

return LandComponent
