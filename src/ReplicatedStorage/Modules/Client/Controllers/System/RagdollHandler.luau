local Jloader = require("@game/ReplicatedStorage/JLoader")
local RagdollHandler = Jloader.CreateHandler({ Name = script.Name })

function RagdollHandler:Load()
	Jloader.GlobalFunctions.RagdollService.Start()
	Jloader.GlobalFunctions.BoneRagdollService.Start()
end

return RagdollHandler
