local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("./Config")
local Types = require("./Types")

local Sounds = {}

function Sounds.Step(leg: BasePart, ground: Types.Ground, speed: number)
	local base = Config.Sounds.Kinds[ground.Kind]
	if not base then return end

	local gait = if speed >= Config.Sounds.RunSpeed then "Run" else "Walk"

	Jloader.GlobalFunctions.SoundService:TryPlay(`{base}.{gait}`, { Parent = leg })
end

function Sounds.MuteDefaults(root: BasePart)
	for _, name in Config.Sounds.Mute do
		local default = root:FindFirstChild(name)

		if default and default:IsA("Sound") and default.Volume ~= 0 then
			default.Volume = 0
		end
	end
end

return Sounds
