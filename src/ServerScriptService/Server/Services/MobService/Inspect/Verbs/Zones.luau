local Jloader = require("@game/ReplicatedStorage/JLoader")

local Verb = { Selects = false }

function Verb.Run(): string
	return table.concat(Jloader.GetService("MobSpawnService"):Describe(), "\n")
end

return Verb
