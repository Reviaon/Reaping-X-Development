local RunService = game:GetService("RunService")

local Config = require("@self/Config")
local Build = require("@self/Build")
local Pose = require("@self/Pose")

local BoneRagdollService = {
	Settings = Config,
}

function BoneRagdollService.Build(model: Model, definition): boolean
	assert(RunService:IsServer(), "BoneRagdollService.Build runs on the server")

	return Build.Body(model, definition)
end

function BoneRagdollService.Start()
	if not RunService:IsClient() then return end

	Pose.Start()
end

function BoneRagdollService.IsRagdolled(model: Model): boolean
	return model:HasTag(Config.Tag)
end

return BoneRagdollService
