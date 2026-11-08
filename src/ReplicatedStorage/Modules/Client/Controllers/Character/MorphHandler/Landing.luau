local Jloader = require("@game/ReplicatedStorage/JLoader")
local LandConfig = require("../MovementHandler/@Components/LandComponent/Config")

local Types = require("./Types")

type Session = Types.Session

local Landing = {}

local AIRBORNE = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local GROUNDED = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function heavy(session: Session)
	local StatusService = Jloader.GlobalFunctions.StatusService
	local character = session.Character
	local settings = LandConfig.Heavy

	if StatusService:CheckStatuses(character, LandConfig.SkipStatuses) then return end

	local clip = session.Entry.land_animation
	local track = if clip then session.Animator:Play(clip, settings.Speed) else nil
	local length = if track and track.Length > 0 then track.Length / settings.Speed else settings.StatusFallback
	local camera = Jloader.GetHandler("CameraHandler")

	if camera then
		camera:Shake(settings.Shake)
	end

	StatusService:SetStatus(character, settings.Status, true, length)
end

function Landing.Start(session: Session)
	local airborneSince: number? = nil

	session.Trove:Connect(session.Humanoid.StateChanged, function(_, new: Enum.HumanoidStateType)
		if AIRBORNE[new] then
			airborneSince = airborneSince or os.clock()
			return
		end

		local since = airborneSince
		airborneSince = nil

		if since and GROUNDED[new] and os.clock() - since >= LandConfig.HeavyAirtime then
			heavy(session)
		end
	end)
end

return Landing
