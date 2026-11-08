local Jloader = require("@game/ReplicatedStorage/JLoader")

local Types = require("./Types")

local Visuals = {}

local relay: any = nil

function Visuals.Play(session: Types.Session, method: string?, info: { [string]: any })
	local path = session.Profile.visuals
	if not path or not method then return end

	info.Character = session.Character

	local payload = { Effect = path, Method = method, Info = info, SkipSender = true }

	Jloader.GlobalFunctions.AttackService:PlayLocal(payload)

	relay = relay or Jloader.GetService("EffectService")

	if relay then
		relay.CreateVisual:Fire("SpawnVisual", payload)
	end
end

function Visuals.Shot(session: Types.Session, name: string?, speed: number?)
	if not name then return end

	Visuals.Play(session, name, { Shot = name, Speed = speed or 1 })
end

return Visuals
