local Jloader = require("@game/ReplicatedStorage/JLoader")

local Types = require("../Types")

type Session = Types.Session

local Run = {}

local SPRINTING = "IsSprinting"

local function set(session: Session, running: boolean)
	session.State.Running = running
	Jloader.GlobalFunctions.StatusService:SetStatus(session.Character, SPRINTING, if running then true else nil)
	session:Speed()
end

function Run.Began(session: Session)
	set(session, true)
end

function Run.Ended(session: Session)
	set(session, false)
end

return Run
