local RunService = game:GetService("RunService")

local Config = require("@self/Config")
local Build = require("@self/Build")
local Knockdown = require("@self/Knockdown")
local Pose = require("@self/Pose")

local BoneRagdollService = {
	Settings = Config,
}

function BoneRagdollService.Build(model: Model, definition): boolean
	assert(RunService:IsServer(), "BoneRagdollService.Build runs on the server")

	return Build.Body(model, definition)
end

function BoneRagdollService.Register(model: Model, definition)
	Knockdown.Register(model, definition)
end

function BoneRagdollService.CanKnockdown(model: Model): boolean
	return RunService:IsServer() and Knockdown.Can(model)
end

function BoneRagdollService.Knockdown(model: Model, duration: number, velocity: Vector3, spin: number?, gravity: number?): boolean
	assert(RunService:IsServer(), "BoneRagdollService.Knockdown runs on the server")

	return Knockdown.Start(model, duration, velocity, spin, gravity)
end

function BoneRagdollService.Start()
	if not RunService:IsClient() then return end

	Pose.Start()
end

function BoneRagdollService.IsRagdolled(model: Model): boolean
	return model:HasTag(Config.Tag)
end

return BoneRagdollService
